import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';

import '../../controller/image_controller.dart';
import '../../helper/global.dart';
import '../../widget/custom_btn.dart';
import '../../widget/custom_loading.dart';

class ImageFeature extends StatefulWidget {
  const ImageFeature({super.key});

  @override
  State<ImageFeature> createState() => _ImageFeatureState();
}

class _ImageFeatureState extends State<ImageFeature> {
  final _c = ImageController();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(
                top: mq.height * .02,
                bottom: mq.height * .02,
                left: mq.width * .04,
                right: mq.width * .04),
            children: [
              // Título
              const Text(
                'AI Image Creator',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue),
              ),

              SizedBox(height: mq.height * .02),

              // Campo de texto
              TextFormField(
                controller: _c.textC,
                textAlign: TextAlign.center,
                minLines: 2,
                maxLines: null,
                onTapOutside: (e) => FocusScope.of(context).unfocus(),
                decoration: const InputDecoration(
                    hintText: 'Descreva a imagem que deseja criar...',
                    hintStyle: TextStyle(fontSize: 13.5),
                    border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.all(Radius.circular(10)))),
              ),

              SizedBox(height: mq.height * .02),

              // Imagem gerada
              Container(
                height: mq.height * .45,
                alignment: Alignment.center,
                child: Obx(() => _aiImage()),
              ),

              SizedBox(height: mq.height * .02),

              // Botões de ação
              Obx(() => _c.status.value == Status.complete
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: _c.downloadImage,
                          icon: const Icon(Icons.save_alt_rounded,
                              color: Colors.blue, size: 28),
                        ),
                        IconButton(
                          onPressed: _c.shareImage,
                          icon: const Icon(Icons.share,
                              color: Colors.blue, size: 28),
                        ),
                      ],
                    )
                  : const SizedBox()),

              SizedBox(height: mq.height * .02),

              // Botão criar
              CustomBtn(onTap: _c.createAIImage, text: 'Criar Imagem'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _aiImage() => ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        child: switch (_c.status.value) {
          Status.none => Lottie.asset('assets/lottie/ai_play.json',
              height: mq.height * .3),
          Status.loading => const CustomLoading(),
          Status.complete => _c.imageBase64.value.isNotEmpty
              ? Image.memory(
                  base64Decode(_c.imageBase64.value),
                  fit: BoxFit.contain,
                )
              : const SizedBox(),
        },
      );
}
