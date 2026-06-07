import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:get/get.dart';
import 'package:http/http.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../apis/apis.dart';
import '../helper/my_dialog.dart';

enum Status { none, loading, complete }

class ImageController extends GetxController {
  final textC = TextEditingController();
  final status = Status.none.obs;
  final url = ''.obs;
  final imageBase64 = ''.obs;

  Future<void> createAIImage() async {
    if (textC.text.trim().isEmpty) {
      MyDialog.info('Descreva a imagem que deseja criar!');
      return;
    }

    status.value = Status.loading;

    final result = await APIs.generateImage(textC.text);

    if (result.isEmpty) {
      status.value = Status.none;
      MyDialog.error('Não foi possível gerar a imagem. Tente novamente!');
      return;
    }

    imageBase64.value = result;
    status.value = Status.complete;
  }

  void downloadImage() async {
    try {
      MyDialog.showLoadingDialog();

      final bytes = base64Decode(imageBase64.value);
      final dir = await getTemporaryDirectory();
      final file = await File('${dir.path}/ai_image.png').writeAsBytes(bytes);

      await ImageGallerySaverPlus.saveFile(file.path).then((result) {
        Get.back();
        MyDialog.success('Imagem salva na galeria!');
      });
    } catch (e) {
      Get.back();
      MyDialog.error('Erro ao salvar imagem!');
      log('downloadImageE: $e');
    }
  }

  void shareImage() async {
    try {
      MyDialog.showLoadingDialog();

      final bytes = base64Decode(imageBase64.value);
      final dir = await getTemporaryDirectory();
      final file = await File('${dir.path}/ai_image.png').writeAsBytes(bytes);

      Get.back();

      await Share.shareXFiles([XFile(file.path)],
          text: 'Imagem criada com IA!');
    } catch (e) {
      Get.back();
      MyDialog.error('Erro ao compartilhar imagem!');
      log('shareImageE: $e');
    }
  }
}
