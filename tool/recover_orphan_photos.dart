// tool/recover_orphan_photos.dart
//
// Cruza arquivos órfãos no Storage Supabase com visitas sem fotos_antes
// vinculadas. Produzido pra recuperar dados de Cleiton/Edilson após o
// bug do INSERT 'open' truncado (2026-05-20/21) — fotos foram parar em
// 'abastecimentos/{authUid}/visita-{hash}-antes-{N}.ext' (sem pasta de
// data) e nunca foram vinculadas na coluna fotos_antes da tabela visitas.
//
// COMO RODAR
// ----------
//   export SUPABASE_URL='https://<proj>.supabase.co'
//   export SUPABASE_SERVICE_KEY='<service-role-key>'
//   dart run tool/recover_orphan_photos.dart \
//       --emails=cleiton@exemplo.com,edilson@exemplo.com \
//       --since=2026-05-19 --until=2026-05-22
//
// Por padrão imprime o JSON da proposta — nenhum UPDATE é executado.
// Use --apply pra rodar os UPDATEs propostos (após revisar).
//
// O cruzamento é POR TEMPO: cada grupo de arquivos órfãos (mesmo hash =
// mesma visita) é vinculado à visita do mesmo promotor cuja
// dia_hora_fotos_antes esteja MAIS PRÓXIMA e anterior ao last_modified
// do grupo, dentro de uma janela de tolerância configurável (default
// 30 min). Se houver ambiguidade (várias visitas dentro da janela), o
// script marca como "ambiguous" pra revisão manual.

import 'dart:convert';
import 'dart:io';

const _orphanFileRegex = r'^visita-(\d+)-antes-(\d+)\.([a-zA-Z0-9]+)$';

Future<void> main(List<String> args) async {
  final supabaseUrl = Platform.environment['SUPABASE_URL'];
  final serviceKey = Platform.environment['SUPABASE_SERVICE_KEY'];
  if (supabaseUrl == null ||
      supabaseUrl.isEmpty ||
      serviceKey == null ||
      serviceKey.isEmpty) {
    stderr.writeln(
        'Defina SUPABASE_URL e SUPABASE_SERVICE_KEY no ambiente antes de rodar.');
    exit(2);
  }

  final emailsArg = _argValue(args, '--emails');
  final since = _argValue(args, '--since') ?? '2026-05-19';
  final until = _argValue(args, '--until') ?? '2026-05-22';
  final toleranciaMin =
      int.tryParse(_argValue(args, '--tolerancia-min') ?? '') ?? 30;
  final apply = args.contains('--apply');

  if (emailsArg == null || emailsArg.isEmpty) {
    stderr.writeln(
        'Use --emails=email1@x.com,email2@y.com pra escolher os promotores.');
    exit(2);
  }
  final emails =
      emailsArg.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  final api = _SupabaseApi(supabaseUrl, serviceKey);

  final propostas = <Map<String, dynamic>>[];
  final naoCasados = <Map<String, dynamic>>[];

  for (final email in emails) {
    stderr.writeln('\n>>> Processando promotor: $email');
    final promotor = await api.getPromotorByEmail(email);
    if (promotor == null) {
      stderr.writeln('   Promotor não encontrado em public.users — pulando.');
      continue;
    }
    final authUid = promotor['uid'] as String?;
    final promotorId = promotor['id'] as int?;
    if (authUid == null || promotorId == null) {
      stderr.writeln(
          '   Sem uid ou id em users — pulando (id=$promotorId, uid=$authUid).');
      continue;
    }
    stderr.writeln('   id=$promotorId  uid=$authUid');

    // Lista arquivos órfãos direto sob abastecimentos/{authUid}/
    final arquivos = await api.listarArquivosOrfaos(authUid);
    stderr.writeln('   Arquivos órfãos encontrados: ${arquivos.length}');

    if (arquivos.isEmpty) continue;

    // Agrupa por hash (todas as fotos com mesmo hash são da mesma visita)
    final grupos = <String, List<_OrphanFile>>{};
    for (final f in arquivos) {
      grupos.putIfAbsent(f.hash, () => []).add(f);
    }
    stderr.writeln('   Grupos (=visitas órfãs): ${grupos.length}');

    // Carrega candidatas: visitas do promotor com fotos_antes vazio
    // e dia_hora_fotos_antes dentro do range.
    final candidatas =
        await api.getVisitasSemFotosAntes(promotorId, since, until);
    stderr.writeln('   Visitas candidatas (sem fotos_antes): ${candidatas.length}');

    // Marca quais candidatas já foram atribuídas (1:1 — uma visita só
    // pode receber um grupo de fotos).
    final atribuidas = <int>{};

    // Ordena grupos por timestamp do arquivo mais recente
    final gruposOrdenados = grupos.entries.toList()
      ..sort((a, b) {
        final ta = a.value
            .map((f) => f.lastModified)
            .reduce((x, y) => x.isAfter(y) ? x : y);
        final tb = b.value
            .map((f) => f.lastModified)
            .reduce((x, y) => x.isAfter(y) ? x : y);
        return ta.compareTo(tb);
      });

    for (final entry in gruposOrdenados) {
      final hash = entry.key;
      final files = entry.value
        ..sort((a, b) => a.numero.compareTo(b.numero));
      final tsUpload = files
          .map((f) => f.lastModified)
          .reduce((x, y) => x.isAfter(y) ? x : y);

      // Acha candidatas dentro da janela de tolerância (dia_hora_fotos_antes
      // <= tsUpload, e tsUpload - dia_hora_fotos_antes <= tolerância)
      final matches = candidatas.where((v) {
        if (atribuidas.contains(v['id'] as int)) return false;
        final dhfaRaw = v['dia_hora_fotos_antes'] as String?;
        if (dhfaRaw == null) return false;
        final dhfa = DateTime.tryParse(dhfaRaw);
        if (dhfa == null) return false;
        final dhfaUtc = dhfa.toUtc();
        final delta = tsUpload.difference(dhfaUtc);
        return delta.inMinutes >= 0 &&
            delta.inMinutes <= toleranciaMin;
      }).toList();

      final urls = files.map((f) => f.publicUrl(supabaseUrl)).toList();

      if (matches.isEmpty) {
        naoCasados.add({
          'promotor_email': email,
          'promotor_id': promotorId,
          'hash': hash,
          'arquivos': urls,
          'last_modified': tsUpload.toIso8601String(),
          'motivo': 'nenhuma visita candidata dentro da janela',
        });
        continue;
      }

      // Pega a candidata com dia_hora_fotos_antes MAIS PRÓXIMA do upload
      matches.sort((a, b) {
        final ta = DateTime.parse(a['dia_hora_fotos_antes'] as String).toUtc();
        final tb = DateTime.parse(b['dia_hora_fotos_antes'] as String).toUtc();
        return ta.compareTo(tb);
      });
      final melhor = matches.last; // mais próxima/anterior

      atribuidas.add(melhor['id'] as int);
      propostas.add({
        'promotor_email': email,
        'promotor_id': promotorId,
        'visita_id': melhor['id'],
        'visita_titulo': melhor['titulo'],
        'dia_hora_fotos_antes': melhor['dia_hora_fotos_antes'],
        'upload_em': tsUpload.toIso8601String(),
        'arquivos': urls,
        'ambiguidade': matches.length > 1
            ? 'multiplas_visitas_na_janela:${matches.length}'
            : 'unica',
      });
    }
  }

  final output = {
    'propostas': propostas,
    'nao_casados': naoCasados,
    'gerado_em': DateTime.now().toUtc().toIso8601String(),
    'apply': apply,
  };

  print(const JsonEncoder.withIndent('  ').convert(output));

  if (!apply) {
    stderr.writeln(
        '\n[DRY-RUN] Nenhum UPDATE executado. Revise o JSON acima e rode com --apply pra aplicar.');
    return;
  }

  stderr.writeln('\n>>> Aplicando ${propostas.length} UPDATEs...');
  var ok = 0;
  var falha = 0;
  for (final p in propostas) {
    try {
      await api.updateFotosAntes(p['visita_id'] as int,
          (p['arquivos'] as List).cast<String>());
      ok++;
      stderr.writeln('   OK visita_id=${p['visita_id']}');
    } catch (e) {
      falha++;
      stderr.writeln('   FALHA visita_id=${p['visita_id']}: $e');
    }
  }
  stderr.writeln('Total: $ok ok, $falha falha(s).');
}

String? _argValue(List<String> args, String flag) {
  final prefix = '$flag=';
  for (final a in args) {
    if (a.startsWith(prefix)) return a.substring(prefix.length);
  }
  return null;
}

class _OrphanFile {
  final String authUid;
  final String name; // ex: visita-110533779-antes-2.jpg
  final String hash; // ex: 110533779
  final int numero; // ex: 2
  final String ext; // ex: jpg
  final DateTime lastModified;
  _OrphanFile({
    required this.authUid,
    required this.name,
    required this.hash,
    required this.numero,
    required this.ext,
    required this.lastModified,
  });

  String publicUrl(String supabaseUrl) {
    return '$supabaseUrl/storage/v1/object/public/Arquivos/abastecimentos/$authUid/$name';
  }
}

class _SupabaseApi {
  final String baseUrl;
  final String serviceKey;
  final HttpClient _client = HttpClient();
  _SupabaseApi(this.baseUrl, this.serviceKey);

  Future<Map<String, dynamic>?> getPromotorByEmail(String email) async {
    // public.users tem id, email, uid (mapeamento pro auth.users.id)
    final resp = await _get(
        '/rest/v1/users?select=id,email,uid&email=eq.${Uri.encodeQueryComponent(email)}');
    final list = jsonDecode(resp) as List<dynamic>;
    if (list.isEmpty) return null;
    return list.first as Map<String, dynamic>;
  }

  Future<List<_OrphanFile>> listarArquivosOrfaos(String authUid) async {
    // Lista o conteúdo direto sob 'abastecimentos/{authUid}/'.
    // Arquivos órfãos têm padrão 'visita-HASH-antes-N.EXT' e last_modified.
    // (Subpastas de data como '2026-05-20_05-00-00' são ignoradas — essas
    //  são uploads bem-sucedidos.)
    final body = jsonEncode({
      'prefix': 'abastecimentos/$authUid',
      'limit': 1000,
      'offset': 0,
    });
    final resp = await _post('/storage/v1/object/list/Arquivos', body);
    final list = jsonDecode(resp) as List<dynamic>;
    final regex = RegExp(_orphanFileRegex);
    final orphans = <_OrphanFile>[];
    for (final item in list) {
      final m = item as Map<String, dynamic>;
      final name = m['name'] as String;
      final match = regex.firstMatch(name);
      if (match == null) continue;
      final hash = match.group(1)!;
      final numero = int.parse(match.group(2)!);
      final ext = match.group(3)!;
      final updatedAt = m['updated_at'] as String? ??
          m['created_at'] as String? ??
          DateTime.now().toIso8601String();
      orphans.add(_OrphanFile(
        authUid: authUid,
        name: name,
        hash: hash,
        numero: numero,
        ext: ext,
        lastModified: DateTime.parse(updatedAt).toUtc(),
      ));
    }
    return orphans;
  }

  Future<List<Map<String, dynamic>>> getVisitasSemFotosAntes(
      int promotorId, String since, String until) async {
    final qs = StringBuffer('/rest/v1/visitas?');
    qs.write('select=id,titulo,dia_hora_fotos_antes,fotos_antes,dia_hora_agendado');
    qs.write('&id_promotor_associado=eq.$promotorId');
    qs.write('&dia_hora_fotos_antes=gte.$since');
    qs.write('&dia_hora_fotos_antes=lte.$until');
    qs.write('&or=(fotos_antes.is.null,fotos_antes.eq.[])');
    qs.write('&order=dia_hora_fotos_antes.asc');
    final resp = await _get(qs.toString());
    final list = jsonDecode(resp) as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }

  Future<void> updateFotosAntes(int visitaId, List<String> urls) async {
    final body = jsonEncode({'fotos_antes': urls});
    await _patch('/rest/v1/visitas?id=eq.$visitaId', body);
  }

  Future<String> _get(String path) async {
    final req = await _client.openUrl('GET', Uri.parse('$baseUrl$path'));
    _injectHeaders(req);
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw 'GET $path -> ${res.statusCode}: $body';
    }
    return body;
  }

  Future<String> _post(String path, String body) async {
    final req = await _client.openUrl('POST', Uri.parse('$baseUrl$path'));
    _injectHeaders(req);
    req.headers.contentType = ContentType.json;
    req.write(body);
    final res = await req.close();
    final respBody = await res.transform(utf8.decoder).join();
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw 'POST $path -> ${res.statusCode}: $respBody';
    }
    return respBody;
  }

  Future<String> _patch(String path, String body) async {
    final req = await _client.openUrl('PATCH', Uri.parse('$baseUrl$path'));
    _injectHeaders(req);
    req.headers.contentType = ContentType.json;
    req.headers.add('Prefer', 'return=minimal');
    req.write(body);
    final res = await req.close();
    final respBody = await res.transform(utf8.decoder).join();
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw 'PATCH $path -> ${res.statusCode}: $respBody';
    }
    return respBody;
  }

  void _injectHeaders(HttpClientRequest req) {
    req.headers.add('apikey', serviceKey);
    req.headers.add('Authorization', 'Bearer $serviceKey');
  }
}
