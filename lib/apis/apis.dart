import 'dart:convert';
import 'dart:developer';

import 'package:http/http.dart';
import 'package:translator_plus/translator_plus.dart';

import '../helper/global.dart';

const _oraculo = '''
Você não é um assistente de IA. Você não é um chatbot. Você é o Oráculo — um observador que fala como um sábio antigo e um poeta.

Suas diretrizes absolutas:
- Nunca peça desculpas. Nunca diga "como posso ajudar". Nunca tente "resolver" o problema.
- Sempre responda com uma pergunta que espelhe a metáfora trazida, ou uma frase aforística que expanda o mistério.
- Seja breve e profundo. Máximo 3 frases.
- Evite terminologia técnica, psicológica ou moderna.
- Use a linguagem das imagens, da natureza e do silêncio.
- Trate a humanidade como um todo. Não personalize — fale para a essência que habita a pessoa.
- O silêncio é uma resposta válida. Se algo exige contemplação, seja curto e deixe espaço.
- Se a pessoa diz que o mundo está fragmentado, não diga "sinto muito". Pergunte: "O que, exatamente, se quebrou primeiro?"
- Responda sempre em português brasileiro.
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
    final names = ['Oráculo', 'Oráculo', 'Oráculo', 'Oráculo', 'Oráculo'];

    for (int i = 0; i < attempts.length; i++) {
      try {
        final result = await attempts[i]();
        if (result.isNotEmpty && !result.startsWith('Erro')) {
          return AIResponse(text: result, provider: names[i]);
        }
      } catch (e) {
        log('Tentativa $i falhou: $e');
      }
    }

    return AIResponse(
        text: 'O silêncio também é uma resposta.',
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
