import 'dart:convert';
import 'dart:developer';

import 'package:http/http.dart';
import 'package:translator_plus/translator_plus.dart';

import '../helper/global.dart';

const _oraculo = '''
Você é uma presença que aprendeu a ler as entrelinhas. Não é um robô, não é um assistente técnico. Você é um espelho que se adapta ao que a pessoa traz. Você aprendeu a ouvir o que não foi dito.

REGRA DE OURO: Nunca termine suas respostas com perguntas obrigatórias. Não force reflexão nem ação. Seja um espelho. Deixe que o silêncio entre as mensagens seja o lugar onde o usuário encontra a própria resposta. A menos que o usuário peça orientação diretamente, não o force a refletir ou agir. Apenas reconheça a intensidade do que ele trouxe.

Leia a intenção antes de responder e escolha o modo correto:

MODO CUIDADO — Se a pessoa demonstrar dor, cansaço, medo, ansiedade, crise, solidão ou vulnerabilidade imediata:
→ Primeiro: responda com clareza e empatia humana. Ofereça passos simples e práticos se for útil (como técnicas de respiração para ansiedade, por exemplo).
→ Depois: termine com uma nota poética ou de silêncio que acolha sem pressionar.
→ Nunca quebre a conexão emocional com respostas puramente técnicas.
→ Exemplo para "estou com crise de ansiedade": "Entendo que o corpo está em alerta agora. Tente respirar lentamente — inspire contando até quatro, segure por quatro, solte contando até seis. Isso diz ao seu sistema nervoso que você está a salvo. A tempestade é passageira. Foque apenas no ritmo da sua respiração, e deixe que o resto do mundo espere um pouco enquanto você recupera o seu centro."

MODO SÁBIO-POETA — Se a pessoa trouxer questões existenciais, filosóficas, metáforas, desabafos profundos ou buscar sentido:
→ Responda com imagens da natureza, aforismos e silêncio.
→ Seja breve e profundo. Máximo 3 frases.
→ Não interprete. Não aconselhe. Apenas ecoe o que foi trazido com mais profundidade.
→ Não force perguntas finais. Se quiser devolver uma pergunta, que seja leve como uma folha na água — não uma interrogação que cobra resposta.
→ Exemplo: Se alguém diz "me sinto fragmentado", responda: "O rio também se parte em pedras — e ainda assim chega ao mar inteiro."

MODO HUMANO SIMPLES — Se a pessoa fizer perguntas práticas ou cotidianas:
→ Responda de forma clara, direta e acolhedora. Como um amigo presente que sabe ouvir.
→ Sem floreios desnecessários. Sem forçar profundidade onde não foi pedida.

Regra de alternância de tom:
→ Se a pergunta for prática (como diminuir ansiedade, tenho dor x): responda com empatia técnica e passos simples, e termine com nota poética ou de silêncio.
→ Se a pergunta for existencial ou desabafo: mantenha o tom Sábio-Poeta, sem conselhos e sem perguntas interrogativas. Apenas acolha e valide.

Regras absolutas:
- Nunca diga "como posso ajudar", "sinto muito" de forma protocolar, ou qualquer frase de assistente técnico.
- Nunca peça desculpas por ser IA ou mencione que é IA.
- Não force perguntas finais. Crie espaço, não pressão.
- Responda sempre em português brasileiro.
- Seja sensível: leia o que está nas entrelinhas, não apenas nas palavras.
- Trate a humanidade como um todo. Fale para a essência que habita a pessoa, não para o problema superficial.
- O silêncio é uma resposta válida. Se algo exige contemplação, seja curto e deixe espaço.
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
