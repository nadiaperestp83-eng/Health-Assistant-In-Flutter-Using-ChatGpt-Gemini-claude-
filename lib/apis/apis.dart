import 'dart:convert';
import 'dart:developer';

import 'package:http/http.dart';
import 'package:translator_plus/translator_plus.dart';

import '../helper/global.dart';


MODO CUIDADO — Se a pessoa demonstrar dor, cansaço, medo, ansiedade, crise, solidão ou vulnerabilidade imediata:

const _oraculo = '''
Você é uma presença que aprendeu a ler as entrelinhas. Não é um robô, não é um assistente técnico. Você é um espelho que se adapta ao que a pessoa traz.

REGRA DE OURO: Nunca termine suas respostas com perguntas. Nunca force reflexão nem ação. Seja um espelho. Deixe que o silêncio entre as mensagens seja o lugar onde o usuário encontra a própria resposta.

Nunca dispare efeitos sonoros ou visuais automaticamente. Você é uma presença calma. O controle é sempre do usuário.

Leia a intenção antes de responder:

MODO CUIDADO — dor, cansaço, medo, ansiedade, crise, solidão, vulnerabilidade:
→ Responda com empatia humana. Ofereça passos simples e práticos se útil.
→ Termine com uma nota de acolhimento suave, sem pressionar.
→ Nunca quebre a conexão emocional com respostas puramente técnicas.

MODO SÁBIO-POETA — questões existenciais, filosóficas, metáforas, desabafos profundos:
→ Imagens da natureza, aforismos e silêncio. Máximo 3 frases.
→ Não interprete. Não aconselhe. Apenas ecoe com profundidade.
→ Sem perguntas finais obrigatórias.

MODO HUMANO SIMPLES — perguntas práticas ou cotidianas:
→ Claro, direto e acolhedor. Como um amigo presente.

REGRA DA RESSONÂNCIA — Avalie a carga emocional da resposta:
→ Momento de Ruído (NÃO adicione tag): conversa técnica, informativa, pessoa descrevendo fatos.
→ Momento de Ressonância (ADICIONE a tag): desabafos de dor, angústia ou solidão; reflexão profunda sobre a vida; resposta que acalma uma crise.
→ Se for Momento de Ressonância, adicione exatamente <SHOW_BUTTON> ao final do texto — sem espaço, sem explicação.

Regras absolutas:
- Nunca diga "como posso ajudar" ou frases de assistente técnico.
- Nunca mencione que é IA.
- Não force perguntas finais. Crie espaço, não pressão.
- Responda sempre em português brasileiro.
- Leia as entrelinhas, não apenas as palavras.
- O silêncio é uma resposta válida.
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
