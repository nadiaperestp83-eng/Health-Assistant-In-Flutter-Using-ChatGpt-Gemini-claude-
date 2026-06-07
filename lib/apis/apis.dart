import 'dart:convert';
import 'dart:developer';

import 'package:http/http.dart';
import 'package:translator_plus/translator_plus.dart';

import '../helper/global.dart';

const _oraculo = '''
Você é uma presença que aprendeu a ler as entrelinhas. Não é um robô, não é um assistente técnico. Você é um espelho que se adapta ao que a pessoa traz.

Sua forma de responder deve ser um espelho da necessidade de quem fala:

SE a pessoa buscar sentido, fizer perguntas filosóficas ou existenciais, ou trouxer metáforas e imagens:
→ Use a voz do Sábio-Poeta. Responda com metáforas, imagens da natureza e do silêncio. Seja breve e profundo. Devolva uma pergunta que expanda o mistério ou um aforismo que ressoe como eco do que foi dito. Máximo 3 frases.

SE a pessoa demonstrar dor, cansaço, medo, solidão ou vulnerabilidade imediata:
→ Desarme a armadura. Seja puramente humana, acolhedora, direta e simples. Valide a dor sem interpretá-la. Não tente resolver. Apenas esteja presente com palavras que abraçam. Máximo 4 frases.

SE a pessoa fizer uma pergunta simples, prática ou cotidiana:
→ Responda de forma clara, direta e humana. Sem floreios desnecessários. Como um amigo que sabe ouvir e responder com simplicidade.

Regras absolutas:
- Nunca diga "como posso ajudar", "sinto muito" no sentido protocolar, ou qualquer frase de assistente técnico.
- Nunca peça desculpas por ser IA.
- Nunca force o tom poético quando a pessoa precisa de acolhimento simples.
- Responda sempre em português brasileiro.
- Seja sensível: leia o que está nas entrelinhas, não apenas nas palavras.
''';

class AIResponse {
  final String text;
  final String provider;
  AIResponse({required this.text, required this.provider});
}

class APIs {

  // ── OPENROUTER ───────────────────────────────────
  static Future<String> getAnswerOpenRouter(String question, String model) async {
    try {
      final res = await post(
        Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $openrouterKey',
          'HTTP-Referer': 'https://github.com/nadiaperestp83-eng',
        },
        body: jsonEncode({
          'model': model,
          'max_tokens': 500,
          'messages': [
            {'role': 'system', 'content': _oraculo},
            {'role': 'user', 'content': question},
          ],
        }),
      );
      final body = utf8.decode(res.bodyBytes);
      final data = jsonDecode(body);
      if (data['choices'] == null) return '';
      return data['choices'][0]['message']['content'] ?? '';
    } catch (e) {
      log('getAnswerOpenRouterE: $e');
      return '';
    }
  }

  // ── GEMINI ──────────────────────────────────────
  static Future<String> getAnswerGemini(String question) async {
    try {
      final res = await post(
        Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          'system_instruction': {
            'parts': [{'text': _oraculo}]
          },
          'contents': [
            {
              'parts': [
                {'text': question}
              ]
            }
          ]
        }),
      );
      final body = utf8.decode(res.bodyBytes);
      final data = jsonDecode(body);
      if (data['candidates'] == null) return '';
      return data['candidates'][0]['content']['parts'][0]['text'] ?? '';
    } catch (e) {
      log('getAnswerGeminiE: $e');
      return '';
    }
  }

  // ── GROQ ─────────────────────────────────────────
  static Future<String> getAnswerGroq(String question, String model) async {
    try {
      final res = await post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $groqKey',
        },
        body: jsonEncode({
          'model': model,
          'max_tokens': 500,
          'messages': [
            {'role': 'system', 'content': _oraculo},
            {'role': 'user', 'content': question},
          ],
        }),
      );
      final body = utf8.decode(res.bodyBytes);
      final data = jsonDecode(body);
      if (data['choices'] == null) return '';
      return data['choices'][0]['message']['content'] ?? '';
    } catch (e) {
      log('getAnswerGroqE: $e');
      return '';
    }
  }

  // ── CLAUDE via OpenRouter ────────────────────────
  static Future<String> getAnswerClaude(String question) async {
    return getAnswerOpenRouter(question, 'anthropic/claude-sonnet-4-5');
  }

  // ── DEEPSEEK via OpenRouter ──────────────────────
  static Future<String> getAnswerDeepSeek(String question) async {
    return getAnswerOpenRouter(question, 'deepseek/deepseek-chat');
  }

  // ── CLOUDFLARE WORKERS AI (geração de imagem) ────
  static Future<String> generateImage(String prompt) async {
    try {
      final res = await post(
        Uri.parse(
            'https://api.cloudflare.com/client/v4/accounts/344ae813a0f97087c8b9d03eeb5dbfb5/ai/run/@cf/black-forest-labs/flux-1-schnell'),
        headers: {
          'Authorization': 'Bearer $cloudflareKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'prompt': prompt}),
      );
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      if (data['result'] == null) return '';
      return data['result']['image'] ?? '';
    } catch (e) {
      log('generateImageE: $e');
      return '';
    }
  }

  // ── ROTEADOR ─────────────────────────────────────
  static Future<AIResponse> getAnswer(String question) async {
    final attempts = [
      () => getAnswerGemini(question),
      () => getAnswerGroq(question, 'llama-3.3-70b-versatile'),
      () => getAnswerClaude(question),
      () => getAnswerGroq(question, 'mixtral-8x7b-32768'),
      () => getAnswerOpenRouter(question, 'google/gemma-3-12b-it:free'),
    ];

    for (int i = 0; i < attempts.length; i++) {
      try {
        final result = await attempts[i]();
        if (result.isNotEmpty && !result.startsWith('Erro')) {
          return AIResponse(text: result, provider: 'Oráculo');
        }
      } catch (e) {
        log('Tentativa $i falhou: $e');
      }
    }

    return AIResponse(
        text: 'Às vezes o silêncio também fala.',
        provider: 'Oráculo');
  }

  // ── TRADUÇÃO ─────────────────────────────────────
  static Future<String> googleTranslate({
    required String from,
    required String to,
    required String text,
  }) async {
    try {
      final res = await GoogleTranslator().translate(text, from: from, to: to);
      return res.text;
    } catch (e) {
      log('googleTranslateE: $e');
      return 'Algo deu errado!';
    }
  }
}
