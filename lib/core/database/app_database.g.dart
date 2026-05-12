// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $UsersTable extends Users with TableInfo<$UsersTable, User> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UsersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _nomeMeta = const VerificationMeta('nome');
  @override
  late final GeneratedColumn<String> nome = GeneratedColumn<String>(
      'nome', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
      'email', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _fotoMeta = const VerificationMeta('foto');
  @override
  late final GeneratedColumn<String> foto = GeneratedColumn<String>(
      'foto', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _tipoUserMeta =
      const VerificationMeta('tipoUser');
  @override
  late final GeneratedColumn<int> tipoUser = GeneratedColumn<int>(
      'tipo_user', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _ativoMeta = const VerificationMeta('ativo');
  @override
  late final GeneratedColumn<bool> ativo = GeneratedColumn<bool>(
      'ativo', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("ativo" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _areaAtuacaoMeta =
      const VerificationMeta('areaAtuacao');
  @override
  late final GeneratedColumn<String> areaAtuacao = GeneratedColumn<String>(
      'area_atuacao', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _telefoneMeta =
      const VerificationMeta('telefone');
  @override
  late final GeneratedColumn<String> telefone = GeneratedColumn<String>(
      'telefone', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _syncedAtMeta =
      const VerificationMeta('syncedAt');
  @override
  late final GeneratedColumn<String> syncedAt = GeneratedColumn<String>(
      'synced_at', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, nome, email, foto, tipoUser, ativo, areaAtuacao, telefone, syncedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'users';
  @override
  VerificationContext validateIntegrity(Insertable<User> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('nome')) {
      context.handle(
          _nomeMeta, nome.isAcceptableOrUnknown(data['nome']!, _nomeMeta));
    }
    if (data.containsKey('email')) {
      context.handle(
          _emailMeta, email.isAcceptableOrUnknown(data['email']!, _emailMeta));
    }
    if (data.containsKey('foto')) {
      context.handle(
          _fotoMeta, foto.isAcceptableOrUnknown(data['foto']!, _fotoMeta));
    }
    if (data.containsKey('tipo_user')) {
      context.handle(_tipoUserMeta,
          tipoUser.isAcceptableOrUnknown(data['tipo_user']!, _tipoUserMeta));
    }
    if (data.containsKey('ativo')) {
      context.handle(
          _ativoMeta, ativo.isAcceptableOrUnknown(data['ativo']!, _ativoMeta));
    }
    if (data.containsKey('area_atuacao')) {
      context.handle(
          _areaAtuacaoMeta,
          areaAtuacao.isAcceptableOrUnknown(
              data['area_atuacao']!, _areaAtuacaoMeta));
    }
    if (data.containsKey('telefone')) {
      context.handle(_telefoneMeta,
          telefone.isAcceptableOrUnknown(data['telefone']!, _telefoneMeta));
    }
    if (data.containsKey('synced_at')) {
      context.handle(_syncedAtMeta,
          syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  User map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return User(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      nome: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}nome']),
      email: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}email']),
      foto: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}foto']),
      tipoUser: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}tipo_user']),
      ativo: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}ativo'])!,
      areaAtuacao: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}area_atuacao']),
      telefone: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}telefone']),
      syncedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}synced_at']),
    );
  }

  @override
  $UsersTable createAlias(String alias) {
    return $UsersTable(attachedDatabase, alias);
  }
}

class User extends DataClass implements Insertable<User> {
  final int id;
  final String? nome;
  final String? email;
  final String? foto;
  final int? tipoUser;
  final bool ativo;
  final String? areaAtuacao;
  final String? telefone;
  final String? syncedAt;
  const User(
      {required this.id,
      this.nome,
      this.email,
      this.foto,
      this.tipoUser,
      required this.ativo,
      this.areaAtuacao,
      this.telefone,
      this.syncedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || nome != null) {
      map['nome'] = Variable<String>(nome);
    }
    if (!nullToAbsent || email != null) {
      map['email'] = Variable<String>(email);
    }
    if (!nullToAbsent || foto != null) {
      map['foto'] = Variable<String>(foto);
    }
    if (!nullToAbsent || tipoUser != null) {
      map['tipo_user'] = Variable<int>(tipoUser);
    }
    map['ativo'] = Variable<bool>(ativo);
    if (!nullToAbsent || areaAtuacao != null) {
      map['area_atuacao'] = Variable<String>(areaAtuacao);
    }
    if (!nullToAbsent || telefone != null) {
      map['telefone'] = Variable<String>(telefone);
    }
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<String>(syncedAt);
    }
    return map;
  }

  UsersCompanion toCompanion(bool nullToAbsent) {
    return UsersCompanion(
      id: Value(id),
      nome: nome == null && nullToAbsent ? const Value.absent() : Value(nome),
      email:
          email == null && nullToAbsent ? const Value.absent() : Value(email),
      foto: foto == null && nullToAbsent ? const Value.absent() : Value(foto),
      tipoUser: tipoUser == null && nullToAbsent
          ? const Value.absent()
          : Value(tipoUser),
      ativo: Value(ativo),
      areaAtuacao: areaAtuacao == null && nullToAbsent
          ? const Value.absent()
          : Value(areaAtuacao),
      telefone: telefone == null && nullToAbsent
          ? const Value.absent()
          : Value(telefone),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
    );
  }

  factory User.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return User(
      id: serializer.fromJson<int>(json['id']),
      nome: serializer.fromJson<String?>(json['nome']),
      email: serializer.fromJson<String?>(json['email']),
      foto: serializer.fromJson<String?>(json['foto']),
      tipoUser: serializer.fromJson<int?>(json['tipoUser']),
      ativo: serializer.fromJson<bool>(json['ativo']),
      areaAtuacao: serializer.fromJson<String?>(json['areaAtuacao']),
      telefone: serializer.fromJson<String?>(json['telefone']),
      syncedAt: serializer.fromJson<String?>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'nome': serializer.toJson<String?>(nome),
      'email': serializer.toJson<String?>(email),
      'foto': serializer.toJson<String?>(foto),
      'tipoUser': serializer.toJson<int?>(tipoUser),
      'ativo': serializer.toJson<bool>(ativo),
      'areaAtuacao': serializer.toJson<String?>(areaAtuacao),
      'telefone': serializer.toJson<String?>(telefone),
      'syncedAt': serializer.toJson<String?>(syncedAt),
    };
  }

  User copyWith(
          {int? id,
          Value<String?> nome = const Value.absent(),
          Value<String?> email = const Value.absent(),
          Value<String?> foto = const Value.absent(),
          Value<int?> tipoUser = const Value.absent(),
          bool? ativo,
          Value<String?> areaAtuacao = const Value.absent(),
          Value<String?> telefone = const Value.absent(),
          Value<String?> syncedAt = const Value.absent()}) =>
      User(
        id: id ?? this.id,
        nome: nome.present ? nome.value : this.nome,
        email: email.present ? email.value : this.email,
        foto: foto.present ? foto.value : this.foto,
        tipoUser: tipoUser.present ? tipoUser.value : this.tipoUser,
        ativo: ativo ?? this.ativo,
        areaAtuacao: areaAtuacao.present ? areaAtuacao.value : this.areaAtuacao,
        telefone: telefone.present ? telefone.value : this.telefone,
        syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
      );
  User copyWithCompanion(UsersCompanion data) {
    return User(
      id: data.id.present ? data.id.value : this.id,
      nome: data.nome.present ? data.nome.value : this.nome,
      email: data.email.present ? data.email.value : this.email,
      foto: data.foto.present ? data.foto.value : this.foto,
      tipoUser: data.tipoUser.present ? data.tipoUser.value : this.tipoUser,
      ativo: data.ativo.present ? data.ativo.value : this.ativo,
      areaAtuacao:
          data.areaAtuacao.present ? data.areaAtuacao.value : this.areaAtuacao,
      telefone: data.telefone.present ? data.telefone.value : this.telefone,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('User(')
          ..write('id: $id, ')
          ..write('nome: $nome, ')
          ..write('email: $email, ')
          ..write('foto: $foto, ')
          ..write('tipoUser: $tipoUser, ')
          ..write('ativo: $ativo, ')
          ..write('areaAtuacao: $areaAtuacao, ')
          ..write('telefone: $telefone, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, nome, email, foto, tipoUser, ativo, areaAtuacao, telefone, syncedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is User &&
          other.id == this.id &&
          other.nome == this.nome &&
          other.email == this.email &&
          other.foto == this.foto &&
          other.tipoUser == this.tipoUser &&
          other.ativo == this.ativo &&
          other.areaAtuacao == this.areaAtuacao &&
          other.telefone == this.telefone &&
          other.syncedAt == this.syncedAt);
}

class UsersCompanion extends UpdateCompanion<User> {
  final Value<int> id;
  final Value<String?> nome;
  final Value<String?> email;
  final Value<String?> foto;
  final Value<int?> tipoUser;
  final Value<bool> ativo;
  final Value<String?> areaAtuacao;
  final Value<String?> telefone;
  final Value<String?> syncedAt;
  const UsersCompanion({
    this.id = const Value.absent(),
    this.nome = const Value.absent(),
    this.email = const Value.absent(),
    this.foto = const Value.absent(),
    this.tipoUser = const Value.absent(),
    this.ativo = const Value.absent(),
    this.areaAtuacao = const Value.absent(),
    this.telefone = const Value.absent(),
    this.syncedAt = const Value.absent(),
  });
  UsersCompanion.insert({
    this.id = const Value.absent(),
    this.nome = const Value.absent(),
    this.email = const Value.absent(),
    this.foto = const Value.absent(),
    this.tipoUser = const Value.absent(),
    this.ativo = const Value.absent(),
    this.areaAtuacao = const Value.absent(),
    this.telefone = const Value.absent(),
    this.syncedAt = const Value.absent(),
  });
  static Insertable<User> custom({
    Expression<int>? id,
    Expression<String>? nome,
    Expression<String>? email,
    Expression<String>? foto,
    Expression<int>? tipoUser,
    Expression<bool>? ativo,
    Expression<String>? areaAtuacao,
    Expression<String>? telefone,
    Expression<String>? syncedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (nome != null) 'nome': nome,
      if (email != null) 'email': email,
      if (foto != null) 'foto': foto,
      if (tipoUser != null) 'tipo_user': tipoUser,
      if (ativo != null) 'ativo': ativo,
      if (areaAtuacao != null) 'area_atuacao': areaAtuacao,
      if (telefone != null) 'telefone': telefone,
      if (syncedAt != null) 'synced_at': syncedAt,
    });
  }

  UsersCompanion copyWith(
      {Value<int>? id,
      Value<String?>? nome,
      Value<String?>? email,
      Value<String?>? foto,
      Value<int?>? tipoUser,
      Value<bool>? ativo,
      Value<String?>? areaAtuacao,
      Value<String?>? telefone,
      Value<String?>? syncedAt}) {
    return UsersCompanion(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      email: email ?? this.email,
      foto: foto ?? this.foto,
      tipoUser: tipoUser ?? this.tipoUser,
      ativo: ativo ?? this.ativo,
      areaAtuacao: areaAtuacao ?? this.areaAtuacao,
      telefone: telefone ?? this.telefone,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (nome.present) {
      map['nome'] = Variable<String>(nome.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (foto.present) {
      map['foto'] = Variable<String>(foto.value);
    }
    if (tipoUser.present) {
      map['tipo_user'] = Variable<int>(tipoUser.value);
    }
    if (ativo.present) {
      map['ativo'] = Variable<bool>(ativo.value);
    }
    if (areaAtuacao.present) {
      map['area_atuacao'] = Variable<String>(areaAtuacao.value);
    }
    if (telefone.present) {
      map['telefone'] = Variable<String>(telefone.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<String>(syncedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UsersCompanion(')
          ..write('id: $id, ')
          ..write('nome: $nome, ')
          ..write('email: $email, ')
          ..write('foto: $foto, ')
          ..write('tipoUser: $tipoUser, ')
          ..write('ativo: $ativo, ')
          ..write('areaAtuacao: $areaAtuacao, ')
          ..write('telefone: $telefone, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }
}

class $PdvsTable extends Pdvs with TableInfo<$PdvsTable, Pdv> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PdvsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _apiLocalNameMeta =
      const VerificationMeta('apiLocalName');
  @override
  late final GeneratedColumn<String> apiLocalName = GeneratedColumn<String>(
      'api_local_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _apiLocalCustomerNameMeta =
      const VerificationMeta('apiLocalCustomerName');
  @override
  late final GeneratedColumn<String> apiLocalCustomerName =
      GeneratedColumn<String>('api_local_customer_name', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _enderecoMeta =
      const VerificationMeta('endereco');
  @override
  late final GeneratedColumn<String> endereco = GeneratedColumn<String>(
      'endereco', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _apiSpecificLocationMeta =
      const VerificationMeta('apiSpecificLocation');
  @override
  late final GeneratedColumn<String> apiSpecificLocation =
      GeneratedColumn<String>('api_specific_location', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _latMeta = const VerificationMeta('lat');
  @override
  late final GeneratedColumn<double> lat = GeneratedColumn<double>(
      'lat', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _lngMeta = const VerificationMeta('lng');
  @override
  late final GeneratedColumn<double> lng = GeneratedColumn<double>(
      'lng', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _situacaoMeta =
      const VerificationMeta('situacao');
  @override
  late final GeneratedColumn<bool> situacao = GeneratedColumn<bool>(
      'situacao', aliasedName, true,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("situacao" IN (0, 1))'));
  static const VerificationMeta _syncedAtMeta =
      const VerificationMeta('syncedAt');
  @override
  late final GeneratedColumn<String> syncedAt = GeneratedColumn<String>(
      'synced_at', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        apiLocalName,
        apiLocalCustomerName,
        endereco,
        apiSpecificLocation,
        lat,
        lng,
        situacao,
        syncedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pdvs';
  @override
  VerificationContext validateIntegrity(Insertable<Pdv> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('api_local_name')) {
      context.handle(
          _apiLocalNameMeta,
          apiLocalName.isAcceptableOrUnknown(
              data['api_local_name']!, _apiLocalNameMeta));
    }
    if (data.containsKey('api_local_customer_name')) {
      context.handle(
          _apiLocalCustomerNameMeta,
          apiLocalCustomerName.isAcceptableOrUnknown(
              data['api_local_customer_name']!, _apiLocalCustomerNameMeta));
    }
    if (data.containsKey('endereco')) {
      context.handle(_enderecoMeta,
          endereco.isAcceptableOrUnknown(data['endereco']!, _enderecoMeta));
    }
    if (data.containsKey('api_specific_location')) {
      context.handle(
          _apiSpecificLocationMeta,
          apiSpecificLocation.isAcceptableOrUnknown(
              data['api_specific_location']!, _apiSpecificLocationMeta));
    }
    if (data.containsKey('lat')) {
      context.handle(
          _latMeta, lat.isAcceptableOrUnknown(data['lat']!, _latMeta));
    }
    if (data.containsKey('lng')) {
      context.handle(
          _lngMeta, lng.isAcceptableOrUnknown(data['lng']!, _lngMeta));
    }
    if (data.containsKey('situacao')) {
      context.handle(_situacaoMeta,
          situacao.isAcceptableOrUnknown(data['situacao']!, _situacaoMeta));
    }
    if (data.containsKey('synced_at')) {
      context.handle(_syncedAtMeta,
          syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Pdv map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Pdv(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      apiLocalName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}api_local_name']),
      apiLocalCustomerName: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}api_local_customer_name']),
      endereco: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}endereco']),
      apiSpecificLocation: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}api_specific_location']),
      lat: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}lat']),
      lng: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}lng']),
      situacao: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}situacao']),
      syncedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}synced_at']),
    );
  }

  @override
  $PdvsTable createAlias(String alias) {
    return $PdvsTable(attachedDatabase, alias);
  }
}

class Pdv extends DataClass implements Insertable<Pdv> {
  final int id;
  final String? apiLocalName;
  final String? apiLocalCustomerName;
  final String? endereco;
  final String? apiSpecificLocation;
  final double? lat;
  final double? lng;
  final bool? situacao;
  final String? syncedAt;
  const Pdv(
      {required this.id,
      this.apiLocalName,
      this.apiLocalCustomerName,
      this.endereco,
      this.apiSpecificLocation,
      this.lat,
      this.lng,
      this.situacao,
      this.syncedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || apiLocalName != null) {
      map['api_local_name'] = Variable<String>(apiLocalName);
    }
    if (!nullToAbsent || apiLocalCustomerName != null) {
      map['api_local_customer_name'] = Variable<String>(apiLocalCustomerName);
    }
    if (!nullToAbsent || endereco != null) {
      map['endereco'] = Variable<String>(endereco);
    }
    if (!nullToAbsent || apiSpecificLocation != null) {
      map['api_specific_location'] = Variable<String>(apiSpecificLocation);
    }
    if (!nullToAbsent || lat != null) {
      map['lat'] = Variable<double>(lat);
    }
    if (!nullToAbsent || lng != null) {
      map['lng'] = Variable<double>(lng);
    }
    if (!nullToAbsent || situacao != null) {
      map['situacao'] = Variable<bool>(situacao);
    }
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<String>(syncedAt);
    }
    return map;
  }

  PdvsCompanion toCompanion(bool nullToAbsent) {
    return PdvsCompanion(
      id: Value(id),
      apiLocalName: apiLocalName == null && nullToAbsent
          ? const Value.absent()
          : Value(apiLocalName),
      apiLocalCustomerName: apiLocalCustomerName == null && nullToAbsent
          ? const Value.absent()
          : Value(apiLocalCustomerName),
      endereco: endereco == null && nullToAbsent
          ? const Value.absent()
          : Value(endereco),
      apiSpecificLocation: apiSpecificLocation == null && nullToAbsent
          ? const Value.absent()
          : Value(apiSpecificLocation),
      lat: lat == null && nullToAbsent ? const Value.absent() : Value(lat),
      lng: lng == null && nullToAbsent ? const Value.absent() : Value(lng),
      situacao: situacao == null && nullToAbsent
          ? const Value.absent()
          : Value(situacao),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
    );
  }

  factory Pdv.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Pdv(
      id: serializer.fromJson<int>(json['id']),
      apiLocalName: serializer.fromJson<String?>(json['apiLocalName']),
      apiLocalCustomerName:
          serializer.fromJson<String?>(json['apiLocalCustomerName']),
      endereco: serializer.fromJson<String?>(json['endereco']),
      apiSpecificLocation:
          serializer.fromJson<String?>(json['apiSpecificLocation']),
      lat: serializer.fromJson<double?>(json['lat']),
      lng: serializer.fromJson<double?>(json['lng']),
      situacao: serializer.fromJson<bool?>(json['situacao']),
      syncedAt: serializer.fromJson<String?>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'apiLocalName': serializer.toJson<String?>(apiLocalName),
      'apiLocalCustomerName': serializer.toJson<String?>(apiLocalCustomerName),
      'endereco': serializer.toJson<String?>(endereco),
      'apiSpecificLocation': serializer.toJson<String?>(apiSpecificLocation),
      'lat': serializer.toJson<double?>(lat),
      'lng': serializer.toJson<double?>(lng),
      'situacao': serializer.toJson<bool?>(situacao),
      'syncedAt': serializer.toJson<String?>(syncedAt),
    };
  }

  Pdv copyWith(
          {int? id,
          Value<String?> apiLocalName = const Value.absent(),
          Value<String?> apiLocalCustomerName = const Value.absent(),
          Value<String?> endereco = const Value.absent(),
          Value<String?> apiSpecificLocation = const Value.absent(),
          Value<double?> lat = const Value.absent(),
          Value<double?> lng = const Value.absent(),
          Value<bool?> situacao = const Value.absent(),
          Value<String?> syncedAt = const Value.absent()}) =>
      Pdv(
        id: id ?? this.id,
        apiLocalName:
            apiLocalName.present ? apiLocalName.value : this.apiLocalName,
        apiLocalCustomerName: apiLocalCustomerName.present
            ? apiLocalCustomerName.value
            : this.apiLocalCustomerName,
        endereco: endereco.present ? endereco.value : this.endereco,
        apiSpecificLocation: apiSpecificLocation.present
            ? apiSpecificLocation.value
            : this.apiSpecificLocation,
        lat: lat.present ? lat.value : this.lat,
        lng: lng.present ? lng.value : this.lng,
        situacao: situacao.present ? situacao.value : this.situacao,
        syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
      );
  Pdv copyWithCompanion(PdvsCompanion data) {
    return Pdv(
      id: data.id.present ? data.id.value : this.id,
      apiLocalName: data.apiLocalName.present
          ? data.apiLocalName.value
          : this.apiLocalName,
      apiLocalCustomerName: data.apiLocalCustomerName.present
          ? data.apiLocalCustomerName.value
          : this.apiLocalCustomerName,
      endereco: data.endereco.present ? data.endereco.value : this.endereco,
      apiSpecificLocation: data.apiSpecificLocation.present
          ? data.apiSpecificLocation.value
          : this.apiSpecificLocation,
      lat: data.lat.present ? data.lat.value : this.lat,
      lng: data.lng.present ? data.lng.value : this.lng,
      situacao: data.situacao.present ? data.situacao.value : this.situacao,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Pdv(')
          ..write('id: $id, ')
          ..write('apiLocalName: $apiLocalName, ')
          ..write('apiLocalCustomerName: $apiLocalCustomerName, ')
          ..write('endereco: $endereco, ')
          ..write('apiSpecificLocation: $apiSpecificLocation, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng, ')
          ..write('situacao: $situacao, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, apiLocalName, apiLocalCustomerName,
      endereco, apiSpecificLocation, lat, lng, situacao, syncedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Pdv &&
          other.id == this.id &&
          other.apiLocalName == this.apiLocalName &&
          other.apiLocalCustomerName == this.apiLocalCustomerName &&
          other.endereco == this.endereco &&
          other.apiSpecificLocation == this.apiSpecificLocation &&
          other.lat == this.lat &&
          other.lng == this.lng &&
          other.situacao == this.situacao &&
          other.syncedAt == this.syncedAt);
}

class PdvsCompanion extends UpdateCompanion<Pdv> {
  final Value<int> id;
  final Value<String?> apiLocalName;
  final Value<String?> apiLocalCustomerName;
  final Value<String?> endereco;
  final Value<String?> apiSpecificLocation;
  final Value<double?> lat;
  final Value<double?> lng;
  final Value<bool?> situacao;
  final Value<String?> syncedAt;
  const PdvsCompanion({
    this.id = const Value.absent(),
    this.apiLocalName = const Value.absent(),
    this.apiLocalCustomerName = const Value.absent(),
    this.endereco = const Value.absent(),
    this.apiSpecificLocation = const Value.absent(),
    this.lat = const Value.absent(),
    this.lng = const Value.absent(),
    this.situacao = const Value.absent(),
    this.syncedAt = const Value.absent(),
  });
  PdvsCompanion.insert({
    this.id = const Value.absent(),
    this.apiLocalName = const Value.absent(),
    this.apiLocalCustomerName = const Value.absent(),
    this.endereco = const Value.absent(),
    this.apiSpecificLocation = const Value.absent(),
    this.lat = const Value.absent(),
    this.lng = const Value.absent(),
    this.situacao = const Value.absent(),
    this.syncedAt = const Value.absent(),
  });
  static Insertable<Pdv> custom({
    Expression<int>? id,
    Expression<String>? apiLocalName,
    Expression<String>? apiLocalCustomerName,
    Expression<String>? endereco,
    Expression<String>? apiSpecificLocation,
    Expression<double>? lat,
    Expression<double>? lng,
    Expression<bool>? situacao,
    Expression<String>? syncedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (apiLocalName != null) 'api_local_name': apiLocalName,
      if (apiLocalCustomerName != null)
        'api_local_customer_name': apiLocalCustomerName,
      if (endereco != null) 'endereco': endereco,
      if (apiSpecificLocation != null)
        'api_specific_location': apiSpecificLocation,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (situacao != null) 'situacao': situacao,
      if (syncedAt != null) 'synced_at': syncedAt,
    });
  }

  PdvsCompanion copyWith(
      {Value<int>? id,
      Value<String?>? apiLocalName,
      Value<String?>? apiLocalCustomerName,
      Value<String?>? endereco,
      Value<String?>? apiSpecificLocation,
      Value<double?>? lat,
      Value<double?>? lng,
      Value<bool?>? situacao,
      Value<String?>? syncedAt}) {
    return PdvsCompanion(
      id: id ?? this.id,
      apiLocalName: apiLocalName ?? this.apiLocalName,
      apiLocalCustomerName: apiLocalCustomerName ?? this.apiLocalCustomerName,
      endereco: endereco ?? this.endereco,
      apiSpecificLocation: apiSpecificLocation ?? this.apiSpecificLocation,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      situacao: situacao ?? this.situacao,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (apiLocalName.present) {
      map['api_local_name'] = Variable<String>(apiLocalName.value);
    }
    if (apiLocalCustomerName.present) {
      map['api_local_customer_name'] =
          Variable<String>(apiLocalCustomerName.value);
    }
    if (endereco.present) {
      map['endereco'] = Variable<String>(endereco.value);
    }
    if (apiSpecificLocation.present) {
      map['api_specific_location'] =
          Variable<String>(apiSpecificLocation.value);
    }
    if (lat.present) {
      map['lat'] = Variable<double>(lat.value);
    }
    if (lng.present) {
      map['lng'] = Variable<double>(lng.value);
    }
    if (situacao.present) {
      map['situacao'] = Variable<bool>(situacao.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<String>(syncedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PdvsCompanion(')
          ..write('id: $id, ')
          ..write('apiLocalName: $apiLocalName, ')
          ..write('apiLocalCustomerName: $apiLocalCustomerName, ')
          ..write('endereco: $endereco, ')
          ..write('apiSpecificLocation: $apiSpecificLocation, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng, ')
          ..write('situacao: $situacao, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }
}

class $GabaritosTable extends Gabaritos
    with TableInfo<$GabaritosTable, Gabarito> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GabaritosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _nomeMeta = const VerificationMeta('nome');
  @override
  late final GeneratedColumn<String> nome = GeneratedColumn<String>(
      'nome', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _pdvAssociadoMeta =
      const VerificationMeta('pdvAssociado');
  @override
  late final GeneratedColumn<int> pdvAssociado = GeneratedColumn<int>(
      'pdv_associado', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _rotaAssociadaMeta =
      const VerificationMeta('rotaAssociada');
  @override
  late final GeneratedColumn<int> rotaAssociada = GeneratedColumn<int>(
      'rota_associada', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _promotorAssociadoMeta =
      const VerificationMeta('promotorAssociado');
  @override
  late final GeneratedColumn<int> promotorAssociado = GeneratedColumn<int>(
      'promotor_associado', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _ativoMeta = const VerificationMeta('ativo');
  @override
  late final GeneratedColumn<bool> ativo = GeneratedColumn<bool>(
      'ativo', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("ativo" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _padraoMeta = const VerificationMeta('padrao');
  @override
  late final GeneratedColumn<bool> padrao = GeneratedColumn<bool>(
      'padrao', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("padrao" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _prazoValidadeMeta =
      const VerificationMeta('prazoValidade');
  @override
  late final GeneratedColumn<String> prazoValidade = GeneratedColumn<String>(
      'prazo_validade', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _syncedAtMeta =
      const VerificationMeta('syncedAt');
  @override
  late final GeneratedColumn<String> syncedAt = GeneratedColumn<String>(
      'synced_at', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        nome,
        pdvAssociado,
        rotaAssociada,
        promotorAssociado,
        ativo,
        padrao,
        prazoValidade,
        syncedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'gabaritos';
  @override
  VerificationContext validateIntegrity(Insertable<Gabarito> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('nome')) {
      context.handle(
          _nomeMeta, nome.isAcceptableOrUnknown(data['nome']!, _nomeMeta));
    }
    if (data.containsKey('pdv_associado')) {
      context.handle(
          _pdvAssociadoMeta,
          pdvAssociado.isAcceptableOrUnknown(
              data['pdv_associado']!, _pdvAssociadoMeta));
    } else if (isInserting) {
      context.missing(_pdvAssociadoMeta);
    }
    if (data.containsKey('rota_associada')) {
      context.handle(
          _rotaAssociadaMeta,
          rotaAssociada.isAcceptableOrUnknown(
              data['rota_associada']!, _rotaAssociadaMeta));
    }
    if (data.containsKey('promotor_associado')) {
      context.handle(
          _promotorAssociadoMeta,
          promotorAssociado.isAcceptableOrUnknown(
              data['promotor_associado']!, _promotorAssociadoMeta));
    }
    if (data.containsKey('ativo')) {
      context.handle(
          _ativoMeta, ativo.isAcceptableOrUnknown(data['ativo']!, _ativoMeta));
    }
    if (data.containsKey('padrao')) {
      context.handle(_padraoMeta,
          padrao.isAcceptableOrUnknown(data['padrao']!, _padraoMeta));
    }
    if (data.containsKey('prazo_validade')) {
      context.handle(
          _prazoValidadeMeta,
          prazoValidade.isAcceptableOrUnknown(
              data['prazo_validade']!, _prazoValidadeMeta));
    }
    if (data.containsKey('synced_at')) {
      context.handle(_syncedAtMeta,
          syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Gabarito map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Gabarito(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      nome: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}nome']),
      pdvAssociado: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}pdv_associado'])!,
      rotaAssociada: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}rota_associada']),
      promotorAssociado: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}promotor_associado']),
      ativo: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}ativo'])!,
      padrao: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}padrao'])!,
      prazoValidade: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}prazo_validade']),
      syncedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}synced_at']),
    );
  }

  @override
  $GabaritosTable createAlias(String alias) {
    return $GabaritosTable(attachedDatabase, alias);
  }
}

class Gabarito extends DataClass implements Insertable<Gabarito> {
  final int id;
  final String? nome;
  final int pdvAssociado;
  final int? rotaAssociada;
  final int? promotorAssociado;
  final bool ativo;
  final bool padrao;
  final String? prazoValidade;
  final String? syncedAt;
  const Gabarito(
      {required this.id,
      this.nome,
      required this.pdvAssociado,
      this.rotaAssociada,
      this.promotorAssociado,
      required this.ativo,
      required this.padrao,
      this.prazoValidade,
      this.syncedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || nome != null) {
      map['nome'] = Variable<String>(nome);
    }
    map['pdv_associado'] = Variable<int>(pdvAssociado);
    if (!nullToAbsent || rotaAssociada != null) {
      map['rota_associada'] = Variable<int>(rotaAssociada);
    }
    if (!nullToAbsent || promotorAssociado != null) {
      map['promotor_associado'] = Variable<int>(promotorAssociado);
    }
    map['ativo'] = Variable<bool>(ativo);
    map['padrao'] = Variable<bool>(padrao);
    if (!nullToAbsent || prazoValidade != null) {
      map['prazo_validade'] = Variable<String>(prazoValidade);
    }
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<String>(syncedAt);
    }
    return map;
  }

  GabaritosCompanion toCompanion(bool nullToAbsent) {
    return GabaritosCompanion(
      id: Value(id),
      nome: nome == null && nullToAbsent ? const Value.absent() : Value(nome),
      pdvAssociado: Value(pdvAssociado),
      rotaAssociada: rotaAssociada == null && nullToAbsent
          ? const Value.absent()
          : Value(rotaAssociada),
      promotorAssociado: promotorAssociado == null && nullToAbsent
          ? const Value.absent()
          : Value(promotorAssociado),
      ativo: Value(ativo),
      padrao: Value(padrao),
      prazoValidade: prazoValidade == null && nullToAbsent
          ? const Value.absent()
          : Value(prazoValidade),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
    );
  }

  factory Gabarito.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Gabarito(
      id: serializer.fromJson<int>(json['id']),
      nome: serializer.fromJson<String?>(json['nome']),
      pdvAssociado: serializer.fromJson<int>(json['pdvAssociado']),
      rotaAssociada: serializer.fromJson<int?>(json['rotaAssociada']),
      promotorAssociado: serializer.fromJson<int?>(json['promotorAssociado']),
      ativo: serializer.fromJson<bool>(json['ativo']),
      padrao: serializer.fromJson<bool>(json['padrao']),
      prazoValidade: serializer.fromJson<String?>(json['prazoValidade']),
      syncedAt: serializer.fromJson<String?>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'nome': serializer.toJson<String?>(nome),
      'pdvAssociado': serializer.toJson<int>(pdvAssociado),
      'rotaAssociada': serializer.toJson<int?>(rotaAssociada),
      'promotorAssociado': serializer.toJson<int?>(promotorAssociado),
      'ativo': serializer.toJson<bool>(ativo),
      'padrao': serializer.toJson<bool>(padrao),
      'prazoValidade': serializer.toJson<String?>(prazoValidade),
      'syncedAt': serializer.toJson<String?>(syncedAt),
    };
  }

  Gabarito copyWith(
          {int? id,
          Value<String?> nome = const Value.absent(),
          int? pdvAssociado,
          Value<int?> rotaAssociada = const Value.absent(),
          Value<int?> promotorAssociado = const Value.absent(),
          bool? ativo,
          bool? padrao,
          Value<String?> prazoValidade = const Value.absent(),
          Value<String?> syncedAt = const Value.absent()}) =>
      Gabarito(
        id: id ?? this.id,
        nome: nome.present ? nome.value : this.nome,
        pdvAssociado: pdvAssociado ?? this.pdvAssociado,
        rotaAssociada:
            rotaAssociada.present ? rotaAssociada.value : this.rotaAssociada,
        promotorAssociado: promotorAssociado.present
            ? promotorAssociado.value
            : this.promotorAssociado,
        ativo: ativo ?? this.ativo,
        padrao: padrao ?? this.padrao,
        prazoValidade:
            prazoValidade.present ? prazoValidade.value : this.prazoValidade,
        syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
      );
  Gabarito copyWithCompanion(GabaritosCompanion data) {
    return Gabarito(
      id: data.id.present ? data.id.value : this.id,
      nome: data.nome.present ? data.nome.value : this.nome,
      pdvAssociado: data.pdvAssociado.present
          ? data.pdvAssociado.value
          : this.pdvAssociado,
      rotaAssociada: data.rotaAssociada.present
          ? data.rotaAssociada.value
          : this.rotaAssociada,
      promotorAssociado: data.promotorAssociado.present
          ? data.promotorAssociado.value
          : this.promotorAssociado,
      ativo: data.ativo.present ? data.ativo.value : this.ativo,
      padrao: data.padrao.present ? data.padrao.value : this.padrao,
      prazoValidade: data.prazoValidade.present
          ? data.prazoValidade.value
          : this.prazoValidade,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Gabarito(')
          ..write('id: $id, ')
          ..write('nome: $nome, ')
          ..write('pdvAssociado: $pdvAssociado, ')
          ..write('rotaAssociada: $rotaAssociada, ')
          ..write('promotorAssociado: $promotorAssociado, ')
          ..write('ativo: $ativo, ')
          ..write('padrao: $padrao, ')
          ..write('prazoValidade: $prazoValidade, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, nome, pdvAssociado, rotaAssociada,
      promotorAssociado, ativo, padrao, prazoValidade, syncedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Gabarito &&
          other.id == this.id &&
          other.nome == this.nome &&
          other.pdvAssociado == this.pdvAssociado &&
          other.rotaAssociada == this.rotaAssociada &&
          other.promotorAssociado == this.promotorAssociado &&
          other.ativo == this.ativo &&
          other.padrao == this.padrao &&
          other.prazoValidade == this.prazoValidade &&
          other.syncedAt == this.syncedAt);
}

class GabaritosCompanion extends UpdateCompanion<Gabarito> {
  final Value<int> id;
  final Value<String?> nome;
  final Value<int> pdvAssociado;
  final Value<int?> rotaAssociada;
  final Value<int?> promotorAssociado;
  final Value<bool> ativo;
  final Value<bool> padrao;
  final Value<String?> prazoValidade;
  final Value<String?> syncedAt;
  const GabaritosCompanion({
    this.id = const Value.absent(),
    this.nome = const Value.absent(),
    this.pdvAssociado = const Value.absent(),
    this.rotaAssociada = const Value.absent(),
    this.promotorAssociado = const Value.absent(),
    this.ativo = const Value.absent(),
    this.padrao = const Value.absent(),
    this.prazoValidade = const Value.absent(),
    this.syncedAt = const Value.absent(),
  });
  GabaritosCompanion.insert({
    this.id = const Value.absent(),
    this.nome = const Value.absent(),
    required int pdvAssociado,
    this.rotaAssociada = const Value.absent(),
    this.promotorAssociado = const Value.absent(),
    this.ativo = const Value.absent(),
    this.padrao = const Value.absent(),
    this.prazoValidade = const Value.absent(),
    this.syncedAt = const Value.absent(),
  }) : pdvAssociado = Value(pdvAssociado);
  static Insertable<Gabarito> custom({
    Expression<int>? id,
    Expression<String>? nome,
    Expression<int>? pdvAssociado,
    Expression<int>? rotaAssociada,
    Expression<int>? promotorAssociado,
    Expression<bool>? ativo,
    Expression<bool>? padrao,
    Expression<String>? prazoValidade,
    Expression<String>? syncedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (nome != null) 'nome': nome,
      if (pdvAssociado != null) 'pdv_associado': pdvAssociado,
      if (rotaAssociada != null) 'rota_associada': rotaAssociada,
      if (promotorAssociado != null) 'promotor_associado': promotorAssociado,
      if (ativo != null) 'ativo': ativo,
      if (padrao != null) 'padrao': padrao,
      if (prazoValidade != null) 'prazo_validade': prazoValidade,
      if (syncedAt != null) 'synced_at': syncedAt,
    });
  }

  GabaritosCompanion copyWith(
      {Value<int>? id,
      Value<String?>? nome,
      Value<int>? pdvAssociado,
      Value<int?>? rotaAssociada,
      Value<int?>? promotorAssociado,
      Value<bool>? ativo,
      Value<bool>? padrao,
      Value<String?>? prazoValidade,
      Value<String?>? syncedAt}) {
    return GabaritosCompanion(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      pdvAssociado: pdvAssociado ?? this.pdvAssociado,
      rotaAssociada: rotaAssociada ?? this.rotaAssociada,
      promotorAssociado: promotorAssociado ?? this.promotorAssociado,
      ativo: ativo ?? this.ativo,
      padrao: padrao ?? this.padrao,
      prazoValidade: prazoValidade ?? this.prazoValidade,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (nome.present) {
      map['nome'] = Variable<String>(nome.value);
    }
    if (pdvAssociado.present) {
      map['pdv_associado'] = Variable<int>(pdvAssociado.value);
    }
    if (rotaAssociada.present) {
      map['rota_associada'] = Variable<int>(rotaAssociada.value);
    }
    if (promotorAssociado.present) {
      map['promotor_associado'] = Variable<int>(promotorAssociado.value);
    }
    if (ativo.present) {
      map['ativo'] = Variable<bool>(ativo.value);
    }
    if (padrao.present) {
      map['padrao'] = Variable<bool>(padrao.value);
    }
    if (prazoValidade.present) {
      map['prazo_validade'] = Variable<String>(prazoValidade.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<String>(syncedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GabaritosCompanion(')
          ..write('id: $id, ')
          ..write('nome: $nome, ')
          ..write('pdvAssociado: $pdvAssociado, ')
          ..write('rotaAssociada: $rotaAssociada, ')
          ..write('promotorAssociado: $promotorAssociado, ')
          ..write('ativo: $ativo, ')
          ..write('padrao: $padrao, ')
          ..write('prazoValidade: $prazoValidade, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }
}

class $VisitasTable extends Visitas with TableInfo<$VisitasTable, Visita> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VisitasTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _idPdvAssociadoMeta =
      const VerificationMeta('idPdvAssociado');
  @override
  late final GeneratedColumn<int> idPdvAssociado = GeneratedColumn<int>(
      'id_pdv_associado', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _idPromotorAssociadoMeta =
      const VerificationMeta('idPromotorAssociado');
  @override
  late final GeneratedColumn<int> idPromotorAssociado = GeneratedColumn<int>(
      'id_promotor_associado', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _diaHoraAgendadoMeta =
      const VerificationMeta('diaHoraAgendado');
  @override
  late final GeneratedColumn<String> diaHoraAgendado = GeneratedColumn<String>(
      'dia_hora_agendado', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _diaHoraRealizadoMeta =
      const VerificationMeta('diaHoraRealizado');
  @override
  late final GeneratedColumn<String> diaHoraRealizado = GeneratedColumn<String>(
      'dia_hora_realizado', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _diaHoraAberturaMeta =
      const VerificationMeta('diaHoraAbertura');
  @override
  late final GeneratedColumn<String> diaHoraAbertura = GeneratedColumn<String>(
      'dia_hora_abertura', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _statusVisitaMeta =
      const VerificationMeta('statusVisita');
  @override
  late final GeneratedColumn<int> statusVisita = GeneratedColumn<int>(
      'status_visita', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _rotaAssociadaMeta =
      const VerificationMeta('rotaAssociada');
  @override
  late final GeneratedColumn<int> rotaAssociada = GeneratedColumn<int>(
      'rota_associada', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _idGabaritoAssociadoMeta =
      const VerificationMeta('idGabaritoAssociado');
  @override
  late final GeneratedColumn<int> idGabaritoAssociado = GeneratedColumn<int>(
      'id_gabarito_associado', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _tituloMeta = const VerificationMeta('titulo');
  @override
  late final GeneratedColumn<String> titulo = GeneratedColumn<String>(
      'titulo', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _previsaoTurnoRealizadaMeta =
      const VerificationMeta('previsaoTurnoRealizada');
  @override
  late final GeneratedColumn<String> previsaoTurnoRealizada =
      GeneratedColumn<String>('previsao_turno_realizada', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _visitaAvulsaMeta =
      const VerificationMeta('visitaAvulsa');
  @override
  late final GeneratedColumn<bool> visitaAvulsa = GeneratedColumn<bool>(
      'visita_avulsa', aliasedName, true,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("visita_avulsa" IN (0, 1))'));
  static const VerificationMeta _serverIdMeta =
      const VerificationMeta('serverId');
  @override
  late final GeneratedColumn<int> serverId = GeneratedColumn<int>(
      'server_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _localizacaoAberturaMeta =
      const VerificationMeta('localizacaoAbertura');
  @override
  late final GeneratedColumn<String> localizacaoAbertura =
      GeneratedColumn<String>('localizacao_abertura', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _localizacaoEncerramentoMeta =
      const VerificationMeta('localizacaoEncerramento');
  @override
  late final GeneratedColumn<String> localizacaoEncerramento =
      GeneratedColumn<String>('localizacao_encerramento', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _diaHoraFotosAntesMeta =
      const VerificationMeta('diaHoraFotosAntes');
  @override
  late final GeneratedColumn<String> diaHoraFotosAntes =
      GeneratedColumn<String>('dia_hora_fotos_antes', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _diaHoraFotosDepoisMeta =
      const VerificationMeta('diaHoraFotosDepois');
  @override
  late final GeneratedColumn<String> diaHoraFotosDepois =
      GeneratedColumn<String>('dia_hora_fotos_depois', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _localizacaoFotosAntesMeta =
      const VerificationMeta('localizacaoFotosAntes');
  @override
  late final GeneratedColumn<String> localizacaoFotosAntes =
      GeneratedColumn<String>('localizacao_fotos_antes', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _localizacaoFotosDepoisMeta =
      const VerificationMeta('localizacaoFotosDepois');
  @override
  late final GeneratedColumn<String> localizacaoFotosDepois =
      GeneratedColumn<String>('localizacao_fotos_depois', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _fotosAntesJsonMeta =
      const VerificationMeta('fotosAntesJson');
  @override
  late final GeneratedColumn<String> fotosAntesJson = GeneratedColumn<String>(
      'fotos_antes_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _fotosDepoisJsonMeta =
      const VerificationMeta('fotosDepoisJson');
  @override
  late final GeneratedColumn<String> fotosDepoisJson = GeneratedColumn<String>(
      'fotos_depois_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _checkPergunta1Meta =
      const VerificationMeta('checkPergunta1');
  @override
  late final GeneratedColumn<bool> checkPergunta1 = GeneratedColumn<bool>(
      'check_pergunta1', aliasedName, true,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("check_pergunta1" IN (0, 1))'));
  static const VerificationMeta _obsPergunta1Meta =
      const VerificationMeta('obsPergunta1');
  @override
  late final GeneratedColumn<String> obsPergunta1 = GeneratedColumn<String>(
      'obs_pergunta1', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _checkPergunta2Meta =
      const VerificationMeta('checkPergunta2');
  @override
  late final GeneratedColumn<bool> checkPergunta2 = GeneratedColumn<bool>(
      'check_pergunta2', aliasedName, true,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("check_pergunta2" IN (0, 1))'));
  static const VerificationMeta _obsPergunta2Meta =
      const VerificationMeta('obsPergunta2');
  @override
  late final GeneratedColumn<String> obsPergunta2 = GeneratedColumn<String>(
      'obs_pergunta2', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _checkPergunta3Meta =
      const VerificationMeta('checkPergunta3');
  @override
  late final GeneratedColumn<bool> checkPergunta3 = GeneratedColumn<bool>(
      'check_pergunta3', aliasedName, true,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("check_pergunta3" IN (0, 1))'));
  static const VerificationMeta _obsPergunta3Meta =
      const VerificationMeta('obsPergunta3');
  @override
  late final GeneratedColumn<String> obsPergunta3 = GeneratedColumn<String>(
      'obs_pergunta3', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _checkPergunta4Meta =
      const VerificationMeta('checkPergunta4');
  @override
  late final GeneratedColumn<bool> checkPergunta4 = GeneratedColumn<bool>(
      'check_pergunta4', aliasedName, true,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("check_pergunta4" IN (0, 1))'));
  static const VerificationMeta _obsPergunta4Meta =
      const VerificationMeta('obsPergunta4');
  @override
  late final GeneratedColumn<String> obsPergunta4 = GeneratedColumn<String>(
      'obs_pergunta4', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _checkPergunta5Meta =
      const VerificationMeta('checkPergunta5');
  @override
  late final GeneratedColumn<bool> checkPergunta5 = GeneratedColumn<bool>(
      'check_pergunta5', aliasedName, true,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("check_pergunta5" IN (0, 1))'));
  static const VerificationMeta _obsPergunta5Meta =
      const VerificationMeta('obsPergunta5');
  @override
  late final GeneratedColumn<String> obsPergunta5 = GeneratedColumn<String>(
      'obs_pergunta5', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _checkPergunta6Meta =
      const VerificationMeta('checkPergunta6');
  @override
  late final GeneratedColumn<bool> checkPergunta6 = GeneratedColumn<bool>(
      'check_pergunta6', aliasedName, true,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("check_pergunta6" IN (0, 1))'));
  static const VerificationMeta _obsPergunta6Meta =
      const VerificationMeta('obsPergunta6');
  @override
  late final GeneratedColumn<String> obsPergunta6 = GeneratedColumn<String>(
      'obs_pergunta6', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _checkPergunta7Meta =
      const VerificationMeta('checkPergunta7');
  @override
  late final GeneratedColumn<bool> checkPergunta7 = GeneratedColumn<bool>(
      'check_pergunta7', aliasedName, true,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("check_pergunta7" IN (0, 1))'));
  static const VerificationMeta _obsPergunta7Meta =
      const VerificationMeta('obsPergunta7');
  @override
  late final GeneratedColumn<String> obsPergunta7 = GeneratedColumn<String>(
      'obs_pergunta7', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _comentariosVisitaMeta =
      const VerificationMeta('comentariosVisita');
  @override
  late final GeneratedColumn<String> comentariosVisita =
      GeneratedColumn<String>('comentarios_visita', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _syncStatusMeta =
      const VerificationMeta('syncStatus');
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
      'sync_status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('synced'));
  static const VerificationMeta _syncedAtMeta =
      const VerificationMeta('syncedAt');
  @override
  late final GeneratedColumn<String> syncedAt = GeneratedColumn<String>(
      'synced_at', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _localStateMeta =
      const VerificationMeta('localState');
  @override
  late final GeneratedColumn<String> localState = GeneratedColumn<String>(
      'local_state', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('idle'));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        idPdvAssociado,
        idPromotorAssociado,
        diaHoraAgendado,
        diaHoraRealizado,
        diaHoraAbertura,
        statusVisita,
        rotaAssociada,
        idGabaritoAssociado,
        titulo,
        previsaoTurnoRealizada,
        visitaAvulsa,
        serverId,
        localizacaoAbertura,
        localizacaoEncerramento,
        diaHoraFotosAntes,
        diaHoraFotosDepois,
        localizacaoFotosAntes,
        localizacaoFotosDepois,
        fotosAntesJson,
        fotosDepoisJson,
        checkPergunta1,
        obsPergunta1,
        checkPergunta2,
        obsPergunta2,
        checkPergunta3,
        obsPergunta3,
        checkPergunta4,
        obsPergunta4,
        checkPergunta5,
        obsPergunta5,
        checkPergunta6,
        obsPergunta6,
        checkPergunta7,
        obsPergunta7,
        comentariosVisita,
        syncStatus,
        syncedAt,
        localState
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'visitas';
  @override
  VerificationContext validateIntegrity(Insertable<Visita> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('id_pdv_associado')) {
      context.handle(
          _idPdvAssociadoMeta,
          idPdvAssociado.isAcceptableOrUnknown(
              data['id_pdv_associado']!, _idPdvAssociadoMeta));
    }
    if (data.containsKey('id_promotor_associado')) {
      context.handle(
          _idPromotorAssociadoMeta,
          idPromotorAssociado.isAcceptableOrUnknown(
              data['id_promotor_associado']!, _idPromotorAssociadoMeta));
    }
    if (data.containsKey('dia_hora_agendado')) {
      context.handle(
          _diaHoraAgendadoMeta,
          diaHoraAgendado.isAcceptableOrUnknown(
              data['dia_hora_agendado']!, _diaHoraAgendadoMeta));
    }
    if (data.containsKey('dia_hora_realizado')) {
      context.handle(
          _diaHoraRealizadoMeta,
          diaHoraRealizado.isAcceptableOrUnknown(
              data['dia_hora_realizado']!, _diaHoraRealizadoMeta));
    }
    if (data.containsKey('dia_hora_abertura')) {
      context.handle(
          _diaHoraAberturaMeta,
          diaHoraAbertura.isAcceptableOrUnknown(
              data['dia_hora_abertura']!, _diaHoraAberturaMeta));
    }
    if (data.containsKey('status_visita')) {
      context.handle(
          _statusVisitaMeta,
          statusVisita.isAcceptableOrUnknown(
              data['status_visita']!, _statusVisitaMeta));
    }
    if (data.containsKey('rota_associada')) {
      context.handle(
          _rotaAssociadaMeta,
          rotaAssociada.isAcceptableOrUnknown(
              data['rota_associada']!, _rotaAssociadaMeta));
    }
    if (data.containsKey('id_gabarito_associado')) {
      context.handle(
          _idGabaritoAssociadoMeta,
          idGabaritoAssociado.isAcceptableOrUnknown(
              data['id_gabarito_associado']!, _idGabaritoAssociadoMeta));
    }
    if (data.containsKey('titulo')) {
      context.handle(_tituloMeta,
          titulo.isAcceptableOrUnknown(data['titulo']!, _tituloMeta));
    }
    if (data.containsKey('previsao_turno_realizada')) {
      context.handle(
          _previsaoTurnoRealizadaMeta,
          previsaoTurnoRealizada.isAcceptableOrUnknown(
              data['previsao_turno_realizada']!, _previsaoTurnoRealizadaMeta));
    }
    if (data.containsKey('visita_avulsa')) {
      context.handle(
          _visitaAvulsaMeta,
          visitaAvulsa.isAcceptableOrUnknown(
              data['visita_avulsa']!, _visitaAvulsaMeta));
    }
    if (data.containsKey('server_id')) {
      context.handle(_serverIdMeta,
          serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta));
    }
    if (data.containsKey('localizacao_abertura')) {
      context.handle(
          _localizacaoAberturaMeta,
          localizacaoAbertura.isAcceptableOrUnknown(
              data['localizacao_abertura']!, _localizacaoAberturaMeta));
    }
    if (data.containsKey('localizacao_encerramento')) {
      context.handle(
          _localizacaoEncerramentoMeta,
          localizacaoEncerramento.isAcceptableOrUnknown(
              data['localizacao_encerramento']!, _localizacaoEncerramentoMeta));
    }
    if (data.containsKey('dia_hora_fotos_antes')) {
      context.handle(
          _diaHoraFotosAntesMeta,
          diaHoraFotosAntes.isAcceptableOrUnknown(
              data['dia_hora_fotos_antes']!, _diaHoraFotosAntesMeta));
    }
    if (data.containsKey('dia_hora_fotos_depois')) {
      context.handle(
          _diaHoraFotosDepoisMeta,
          diaHoraFotosDepois.isAcceptableOrUnknown(
              data['dia_hora_fotos_depois']!, _diaHoraFotosDepoisMeta));
    }
    if (data.containsKey('localizacao_fotos_antes')) {
      context.handle(
          _localizacaoFotosAntesMeta,
          localizacaoFotosAntes.isAcceptableOrUnknown(
              data['localizacao_fotos_antes']!, _localizacaoFotosAntesMeta));
    }
    if (data.containsKey('localizacao_fotos_depois')) {
      context.handle(
          _localizacaoFotosDepoisMeta,
          localizacaoFotosDepois.isAcceptableOrUnknown(
              data['localizacao_fotos_depois']!, _localizacaoFotosDepoisMeta));
    }
    if (data.containsKey('fotos_antes_json')) {
      context.handle(
          _fotosAntesJsonMeta,
          fotosAntesJson.isAcceptableOrUnknown(
              data['fotos_antes_json']!, _fotosAntesJsonMeta));
    }
    if (data.containsKey('fotos_depois_json')) {
      context.handle(
          _fotosDepoisJsonMeta,
          fotosDepoisJson.isAcceptableOrUnknown(
              data['fotos_depois_json']!, _fotosDepoisJsonMeta));
    }
    if (data.containsKey('check_pergunta1')) {
      context.handle(
          _checkPergunta1Meta,
          checkPergunta1.isAcceptableOrUnknown(
              data['check_pergunta1']!, _checkPergunta1Meta));
    }
    if (data.containsKey('obs_pergunta1')) {
      context.handle(
          _obsPergunta1Meta,
          obsPergunta1.isAcceptableOrUnknown(
              data['obs_pergunta1']!, _obsPergunta1Meta));
    }
    if (data.containsKey('check_pergunta2')) {
      context.handle(
          _checkPergunta2Meta,
          checkPergunta2.isAcceptableOrUnknown(
              data['check_pergunta2']!, _checkPergunta2Meta));
    }
    if (data.containsKey('obs_pergunta2')) {
      context.handle(
          _obsPergunta2Meta,
          obsPergunta2.isAcceptableOrUnknown(
              data['obs_pergunta2']!, _obsPergunta2Meta));
    }
    if (data.containsKey('check_pergunta3')) {
      context.handle(
          _checkPergunta3Meta,
          checkPergunta3.isAcceptableOrUnknown(
              data['check_pergunta3']!, _checkPergunta3Meta));
    }
    if (data.containsKey('obs_pergunta3')) {
      context.handle(
          _obsPergunta3Meta,
          obsPergunta3.isAcceptableOrUnknown(
              data['obs_pergunta3']!, _obsPergunta3Meta));
    }
    if (data.containsKey('check_pergunta4')) {
      context.handle(
          _checkPergunta4Meta,
          checkPergunta4.isAcceptableOrUnknown(
              data['check_pergunta4']!, _checkPergunta4Meta));
    }
    if (data.containsKey('obs_pergunta4')) {
      context.handle(
          _obsPergunta4Meta,
          obsPergunta4.isAcceptableOrUnknown(
              data['obs_pergunta4']!, _obsPergunta4Meta));
    }
    if (data.containsKey('check_pergunta5')) {
      context.handle(
          _checkPergunta5Meta,
          checkPergunta5.isAcceptableOrUnknown(
              data['check_pergunta5']!, _checkPergunta5Meta));
    }
    if (data.containsKey('obs_pergunta5')) {
      context.handle(
          _obsPergunta5Meta,
          obsPergunta5.isAcceptableOrUnknown(
              data['obs_pergunta5']!, _obsPergunta5Meta));
    }
    if (data.containsKey('check_pergunta6')) {
      context.handle(
          _checkPergunta6Meta,
          checkPergunta6.isAcceptableOrUnknown(
              data['check_pergunta6']!, _checkPergunta6Meta));
    }
    if (data.containsKey('obs_pergunta6')) {
      context.handle(
          _obsPergunta6Meta,
          obsPergunta6.isAcceptableOrUnknown(
              data['obs_pergunta6']!, _obsPergunta6Meta));
    }
    if (data.containsKey('check_pergunta7')) {
      context.handle(
          _checkPergunta7Meta,
          checkPergunta7.isAcceptableOrUnknown(
              data['check_pergunta7']!, _checkPergunta7Meta));
    }
    if (data.containsKey('obs_pergunta7')) {
      context.handle(
          _obsPergunta7Meta,
          obsPergunta7.isAcceptableOrUnknown(
              data['obs_pergunta7']!, _obsPergunta7Meta));
    }
    if (data.containsKey('comentarios_visita')) {
      context.handle(
          _comentariosVisitaMeta,
          comentariosVisita.isAcceptableOrUnknown(
              data['comentarios_visita']!, _comentariosVisitaMeta));
    }
    if (data.containsKey('sync_status')) {
      context.handle(
          _syncStatusMeta,
          syncStatus.isAcceptableOrUnknown(
              data['sync_status']!, _syncStatusMeta));
    }
    if (data.containsKey('synced_at')) {
      context.handle(_syncedAtMeta,
          syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta));
    }
    if (data.containsKey('local_state')) {
      context.handle(
          _localStateMeta,
          localState.isAcceptableOrUnknown(
              data['local_state']!, _localStateMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Visita map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Visita(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      idPdvAssociado: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id_pdv_associado']),
      idPromotorAssociado: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}id_promotor_associado']),
      diaHoraAgendado: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}dia_hora_agendado']),
      diaHoraRealizado: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}dia_hora_realizado']),
      diaHoraAbertura: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}dia_hora_abertura']),
      statusVisita: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}status_visita']),
      rotaAssociada: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}rota_associada']),
      idGabaritoAssociado: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}id_gabarito_associado']),
      titulo: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}titulo']),
      previsaoTurnoRealizada: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}previsao_turno_realizada']),
      visitaAvulsa: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}visita_avulsa']),
      serverId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}server_id']),
      localizacaoAbertura: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}localizacao_abertura']),
      localizacaoEncerramento: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}localizacao_encerramento']),
      diaHoraFotosAntes: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}dia_hora_fotos_antes']),
      diaHoraFotosDepois: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}dia_hora_fotos_depois']),
      localizacaoFotosAntes: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}localizacao_fotos_antes']),
      localizacaoFotosDepois: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}localizacao_fotos_depois']),
      fotosAntesJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}fotos_antes_json']),
      fotosDepoisJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}fotos_depois_json']),
      checkPergunta1: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}check_pergunta1']),
      obsPergunta1: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}obs_pergunta1']),
      checkPergunta2: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}check_pergunta2']),
      obsPergunta2: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}obs_pergunta2']),
      checkPergunta3: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}check_pergunta3']),
      obsPergunta3: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}obs_pergunta3']),
      checkPergunta4: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}check_pergunta4']),
      obsPergunta4: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}obs_pergunta4']),
      checkPergunta5: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}check_pergunta5']),
      obsPergunta5: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}obs_pergunta5']),
      checkPergunta6: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}check_pergunta6']),
      obsPergunta6: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}obs_pergunta6']),
      checkPergunta7: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}check_pergunta7']),
      obsPergunta7: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}obs_pergunta7']),
      comentariosVisita: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}comentarios_visita']),
      syncStatus: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sync_status'])!,
      syncedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}synced_at']),
      localState: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}local_state'])!,
    );
  }

  @override
  $VisitasTable createAlias(String alias) {
    return $VisitasTable(attachedDatabase, alias);
  }
}

class Visita extends DataClass implements Insertable<Visita> {
  final int id;
  final int? idPdvAssociado;
  final int? idPromotorAssociado;
  final String? diaHoraAgendado;
  final String? diaHoraRealizado;
  final String? diaHoraAbertura;
  final int? statusVisita;
  final int? rotaAssociada;
  final int? idGabaritoAssociado;
  final String? titulo;
  final String? previsaoTurnoRealizada;
  final bool? visitaAvulsa;
  final int? serverId;
  final String? localizacaoAbertura;
  final String? localizacaoEncerramento;
  final String? diaHoraFotosAntes;
  final String? diaHoraFotosDepois;
  final String? localizacaoFotosAntes;
  final String? localizacaoFotosDepois;
  final String? fotosAntesJson;
  final String? fotosDepoisJson;
  final bool? checkPergunta1;
  final String? obsPergunta1;
  final bool? checkPergunta2;
  final String? obsPergunta2;
  final bool? checkPergunta3;
  final String? obsPergunta3;
  final bool? checkPergunta4;
  final String? obsPergunta4;
  final bool? checkPergunta5;
  final String? obsPergunta5;
  final bool? checkPergunta6;
  final String? obsPergunta6;
  final bool? checkPergunta7;
  final String? obsPergunta7;
  final String? comentariosVisita;
  final String syncStatus;
  final String? syncedAt;
  final String localState;
  const Visita(
      {required this.id,
      this.idPdvAssociado,
      this.idPromotorAssociado,
      this.diaHoraAgendado,
      this.diaHoraRealizado,
      this.diaHoraAbertura,
      this.statusVisita,
      this.rotaAssociada,
      this.idGabaritoAssociado,
      this.titulo,
      this.previsaoTurnoRealizada,
      this.visitaAvulsa,
      this.serverId,
      this.localizacaoAbertura,
      this.localizacaoEncerramento,
      this.diaHoraFotosAntes,
      this.diaHoraFotosDepois,
      this.localizacaoFotosAntes,
      this.localizacaoFotosDepois,
      this.fotosAntesJson,
      this.fotosDepoisJson,
      this.checkPergunta1,
      this.obsPergunta1,
      this.checkPergunta2,
      this.obsPergunta2,
      this.checkPergunta3,
      this.obsPergunta3,
      this.checkPergunta4,
      this.obsPergunta4,
      this.checkPergunta5,
      this.obsPergunta5,
      this.checkPergunta6,
      this.obsPergunta6,
      this.checkPergunta7,
      this.obsPergunta7,
      this.comentariosVisita,
      required this.syncStatus,
      this.syncedAt,
      required this.localState});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || idPdvAssociado != null) {
      map['id_pdv_associado'] = Variable<int>(idPdvAssociado);
    }
    if (!nullToAbsent || idPromotorAssociado != null) {
      map['id_promotor_associado'] = Variable<int>(idPromotorAssociado);
    }
    if (!nullToAbsent || diaHoraAgendado != null) {
      map['dia_hora_agendado'] = Variable<String>(diaHoraAgendado);
    }
    if (!nullToAbsent || diaHoraRealizado != null) {
      map['dia_hora_realizado'] = Variable<String>(diaHoraRealizado);
    }
    if (!nullToAbsent || diaHoraAbertura != null) {
      map['dia_hora_abertura'] = Variable<String>(diaHoraAbertura);
    }
    if (!nullToAbsent || statusVisita != null) {
      map['status_visita'] = Variable<int>(statusVisita);
    }
    if (!nullToAbsent || rotaAssociada != null) {
      map['rota_associada'] = Variable<int>(rotaAssociada);
    }
    if (!nullToAbsent || idGabaritoAssociado != null) {
      map['id_gabarito_associado'] = Variable<int>(idGabaritoAssociado);
    }
    if (!nullToAbsent || titulo != null) {
      map['titulo'] = Variable<String>(titulo);
    }
    if (!nullToAbsent || previsaoTurnoRealizada != null) {
      map['previsao_turno_realizada'] =
          Variable<String>(previsaoTurnoRealizada);
    }
    if (!nullToAbsent || visitaAvulsa != null) {
      map['visita_avulsa'] = Variable<bool>(visitaAvulsa);
    }
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<int>(serverId);
    }
    if (!nullToAbsent || localizacaoAbertura != null) {
      map['localizacao_abertura'] = Variable<String>(localizacaoAbertura);
    }
    if (!nullToAbsent || localizacaoEncerramento != null) {
      map['localizacao_encerramento'] =
          Variable<String>(localizacaoEncerramento);
    }
    if (!nullToAbsent || diaHoraFotosAntes != null) {
      map['dia_hora_fotos_antes'] = Variable<String>(diaHoraFotosAntes);
    }
    if (!nullToAbsent || diaHoraFotosDepois != null) {
      map['dia_hora_fotos_depois'] = Variable<String>(diaHoraFotosDepois);
    }
    if (!nullToAbsent || localizacaoFotosAntes != null) {
      map['localizacao_fotos_antes'] = Variable<String>(localizacaoFotosAntes);
    }
    if (!nullToAbsent || localizacaoFotosDepois != null) {
      map['localizacao_fotos_depois'] =
          Variable<String>(localizacaoFotosDepois);
    }
    if (!nullToAbsent || fotosAntesJson != null) {
      map['fotos_antes_json'] = Variable<String>(fotosAntesJson);
    }
    if (!nullToAbsent || fotosDepoisJson != null) {
      map['fotos_depois_json'] = Variable<String>(fotosDepoisJson);
    }
    if (!nullToAbsent || checkPergunta1 != null) {
      map['check_pergunta1'] = Variable<bool>(checkPergunta1);
    }
    if (!nullToAbsent || obsPergunta1 != null) {
      map['obs_pergunta1'] = Variable<String>(obsPergunta1);
    }
    if (!nullToAbsent || checkPergunta2 != null) {
      map['check_pergunta2'] = Variable<bool>(checkPergunta2);
    }
    if (!nullToAbsent || obsPergunta2 != null) {
      map['obs_pergunta2'] = Variable<String>(obsPergunta2);
    }
    if (!nullToAbsent || checkPergunta3 != null) {
      map['check_pergunta3'] = Variable<bool>(checkPergunta3);
    }
    if (!nullToAbsent || obsPergunta3 != null) {
      map['obs_pergunta3'] = Variable<String>(obsPergunta3);
    }
    if (!nullToAbsent || checkPergunta4 != null) {
      map['check_pergunta4'] = Variable<bool>(checkPergunta4);
    }
    if (!nullToAbsent || obsPergunta4 != null) {
      map['obs_pergunta4'] = Variable<String>(obsPergunta4);
    }
    if (!nullToAbsent || checkPergunta5 != null) {
      map['check_pergunta5'] = Variable<bool>(checkPergunta5);
    }
    if (!nullToAbsent || obsPergunta5 != null) {
      map['obs_pergunta5'] = Variable<String>(obsPergunta5);
    }
    if (!nullToAbsent || checkPergunta6 != null) {
      map['check_pergunta6'] = Variable<bool>(checkPergunta6);
    }
    if (!nullToAbsent || obsPergunta6 != null) {
      map['obs_pergunta6'] = Variable<String>(obsPergunta6);
    }
    if (!nullToAbsent || checkPergunta7 != null) {
      map['check_pergunta7'] = Variable<bool>(checkPergunta7);
    }
    if (!nullToAbsent || obsPergunta7 != null) {
      map['obs_pergunta7'] = Variable<String>(obsPergunta7);
    }
    if (!nullToAbsent || comentariosVisita != null) {
      map['comentarios_visita'] = Variable<String>(comentariosVisita);
    }
    map['sync_status'] = Variable<String>(syncStatus);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<String>(syncedAt);
    }
    map['local_state'] = Variable<String>(localState);
    return map;
  }

  VisitasCompanion toCompanion(bool nullToAbsent) {
    return VisitasCompanion(
      id: Value(id),
      idPdvAssociado: idPdvAssociado == null && nullToAbsent
          ? const Value.absent()
          : Value(idPdvAssociado),
      idPromotorAssociado: idPromotorAssociado == null && nullToAbsent
          ? const Value.absent()
          : Value(idPromotorAssociado),
      diaHoraAgendado: diaHoraAgendado == null && nullToAbsent
          ? const Value.absent()
          : Value(diaHoraAgendado),
      diaHoraRealizado: diaHoraRealizado == null && nullToAbsent
          ? const Value.absent()
          : Value(diaHoraRealizado),
      diaHoraAbertura: diaHoraAbertura == null && nullToAbsent
          ? const Value.absent()
          : Value(diaHoraAbertura),
      statusVisita: statusVisita == null && nullToAbsent
          ? const Value.absent()
          : Value(statusVisita),
      rotaAssociada: rotaAssociada == null && nullToAbsent
          ? const Value.absent()
          : Value(rotaAssociada),
      idGabaritoAssociado: idGabaritoAssociado == null && nullToAbsent
          ? const Value.absent()
          : Value(idGabaritoAssociado),
      titulo:
          titulo == null && nullToAbsent ? const Value.absent() : Value(titulo),
      previsaoTurnoRealizada: previsaoTurnoRealizada == null && nullToAbsent
          ? const Value.absent()
          : Value(previsaoTurnoRealizada),
      visitaAvulsa: visitaAvulsa == null && nullToAbsent
          ? const Value.absent()
          : Value(visitaAvulsa),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      localizacaoAbertura: localizacaoAbertura == null && nullToAbsent
          ? const Value.absent()
          : Value(localizacaoAbertura),
      localizacaoEncerramento: localizacaoEncerramento == null && nullToAbsent
          ? const Value.absent()
          : Value(localizacaoEncerramento),
      diaHoraFotosAntes: diaHoraFotosAntes == null && nullToAbsent
          ? const Value.absent()
          : Value(diaHoraFotosAntes),
      diaHoraFotosDepois: diaHoraFotosDepois == null && nullToAbsent
          ? const Value.absent()
          : Value(diaHoraFotosDepois),
      localizacaoFotosAntes: localizacaoFotosAntes == null && nullToAbsent
          ? const Value.absent()
          : Value(localizacaoFotosAntes),
      localizacaoFotosDepois: localizacaoFotosDepois == null && nullToAbsent
          ? const Value.absent()
          : Value(localizacaoFotosDepois),
      fotosAntesJson: fotosAntesJson == null && nullToAbsent
          ? const Value.absent()
          : Value(fotosAntesJson),
      fotosDepoisJson: fotosDepoisJson == null && nullToAbsent
          ? const Value.absent()
          : Value(fotosDepoisJson),
      checkPergunta1: checkPergunta1 == null && nullToAbsent
          ? const Value.absent()
          : Value(checkPergunta1),
      obsPergunta1: obsPergunta1 == null && nullToAbsent
          ? const Value.absent()
          : Value(obsPergunta1),
      checkPergunta2: checkPergunta2 == null && nullToAbsent
          ? const Value.absent()
          : Value(checkPergunta2),
      obsPergunta2: obsPergunta2 == null && nullToAbsent
          ? const Value.absent()
          : Value(obsPergunta2),
      checkPergunta3: checkPergunta3 == null && nullToAbsent
          ? const Value.absent()
          : Value(checkPergunta3),
      obsPergunta3: obsPergunta3 == null && nullToAbsent
          ? const Value.absent()
          : Value(obsPergunta3),
      checkPergunta4: checkPergunta4 == null && nullToAbsent
          ? const Value.absent()
          : Value(checkPergunta4),
      obsPergunta4: obsPergunta4 == null && nullToAbsent
          ? const Value.absent()
          : Value(obsPergunta4),
      checkPergunta5: checkPergunta5 == null && nullToAbsent
          ? const Value.absent()
          : Value(checkPergunta5),
      obsPergunta5: obsPergunta5 == null && nullToAbsent
          ? const Value.absent()
          : Value(obsPergunta5),
      checkPergunta6: checkPergunta6 == null && nullToAbsent
          ? const Value.absent()
          : Value(checkPergunta6),
      obsPergunta6: obsPergunta6 == null && nullToAbsent
          ? const Value.absent()
          : Value(obsPergunta6),
      checkPergunta7: checkPergunta7 == null && nullToAbsent
          ? const Value.absent()
          : Value(checkPergunta7),
      obsPergunta7: obsPergunta7 == null && nullToAbsent
          ? const Value.absent()
          : Value(obsPergunta7),
      comentariosVisita: comentariosVisita == null && nullToAbsent
          ? const Value.absent()
          : Value(comentariosVisita),
      syncStatus: Value(syncStatus),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
      localState: Value(localState),
    );
  }

  factory Visita.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Visita(
      id: serializer.fromJson<int>(json['id']),
      idPdvAssociado: serializer.fromJson<int?>(json['idPdvAssociado']),
      idPromotorAssociado:
          serializer.fromJson<int?>(json['idPromotorAssociado']),
      diaHoraAgendado: serializer.fromJson<String?>(json['diaHoraAgendado']),
      diaHoraRealizado: serializer.fromJson<String?>(json['diaHoraRealizado']),
      diaHoraAbertura: serializer.fromJson<String?>(json['diaHoraAbertura']),
      statusVisita: serializer.fromJson<int?>(json['statusVisita']),
      rotaAssociada: serializer.fromJson<int?>(json['rotaAssociada']),
      idGabaritoAssociado:
          serializer.fromJson<int?>(json['idGabaritoAssociado']),
      titulo: serializer.fromJson<String?>(json['titulo']),
      previsaoTurnoRealizada:
          serializer.fromJson<String?>(json['previsaoTurnoRealizada']),
      visitaAvulsa: serializer.fromJson<bool?>(json['visitaAvulsa']),
      serverId: serializer.fromJson<int?>(json['serverId']),
      localizacaoAbertura:
          serializer.fromJson<String?>(json['localizacaoAbertura']),
      localizacaoEncerramento:
          serializer.fromJson<String?>(json['localizacaoEncerramento']),
      diaHoraFotosAntes:
          serializer.fromJson<String?>(json['diaHoraFotosAntes']),
      diaHoraFotosDepois:
          serializer.fromJson<String?>(json['diaHoraFotosDepois']),
      localizacaoFotosAntes:
          serializer.fromJson<String?>(json['localizacaoFotosAntes']),
      localizacaoFotosDepois:
          serializer.fromJson<String?>(json['localizacaoFotosDepois']),
      fotosAntesJson: serializer.fromJson<String?>(json['fotosAntesJson']),
      fotosDepoisJson: serializer.fromJson<String?>(json['fotosDepoisJson']),
      checkPergunta1: serializer.fromJson<bool?>(json['checkPergunta1']),
      obsPergunta1: serializer.fromJson<String?>(json['obsPergunta1']),
      checkPergunta2: serializer.fromJson<bool?>(json['checkPergunta2']),
      obsPergunta2: serializer.fromJson<String?>(json['obsPergunta2']),
      checkPergunta3: serializer.fromJson<bool?>(json['checkPergunta3']),
      obsPergunta3: serializer.fromJson<String?>(json['obsPergunta3']),
      checkPergunta4: serializer.fromJson<bool?>(json['checkPergunta4']),
      obsPergunta4: serializer.fromJson<String?>(json['obsPergunta4']),
      checkPergunta5: serializer.fromJson<bool?>(json['checkPergunta5']),
      obsPergunta5: serializer.fromJson<String?>(json['obsPergunta5']),
      checkPergunta6: serializer.fromJson<bool?>(json['checkPergunta6']),
      obsPergunta6: serializer.fromJson<String?>(json['obsPergunta6']),
      checkPergunta7: serializer.fromJson<bool?>(json['checkPergunta7']),
      obsPergunta7: serializer.fromJson<String?>(json['obsPergunta7']),
      comentariosVisita:
          serializer.fromJson<String?>(json['comentariosVisita']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      syncedAt: serializer.fromJson<String?>(json['syncedAt']),
      localState: serializer.fromJson<String>(json['localState']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'idPdvAssociado': serializer.toJson<int?>(idPdvAssociado),
      'idPromotorAssociado': serializer.toJson<int?>(idPromotorAssociado),
      'diaHoraAgendado': serializer.toJson<String?>(diaHoraAgendado),
      'diaHoraRealizado': serializer.toJson<String?>(diaHoraRealizado),
      'diaHoraAbertura': serializer.toJson<String?>(diaHoraAbertura),
      'statusVisita': serializer.toJson<int?>(statusVisita),
      'rotaAssociada': serializer.toJson<int?>(rotaAssociada),
      'idGabaritoAssociado': serializer.toJson<int?>(idGabaritoAssociado),
      'titulo': serializer.toJson<String?>(titulo),
      'previsaoTurnoRealizada':
          serializer.toJson<String?>(previsaoTurnoRealizada),
      'visitaAvulsa': serializer.toJson<bool?>(visitaAvulsa),
      'serverId': serializer.toJson<int?>(serverId),
      'localizacaoAbertura': serializer.toJson<String?>(localizacaoAbertura),
      'localizacaoEncerramento':
          serializer.toJson<String?>(localizacaoEncerramento),
      'diaHoraFotosAntes': serializer.toJson<String?>(diaHoraFotosAntes),
      'diaHoraFotosDepois': serializer.toJson<String?>(diaHoraFotosDepois),
      'localizacaoFotosAntes':
          serializer.toJson<String?>(localizacaoFotosAntes),
      'localizacaoFotosDepois':
          serializer.toJson<String?>(localizacaoFotosDepois),
      'fotosAntesJson': serializer.toJson<String?>(fotosAntesJson),
      'fotosDepoisJson': serializer.toJson<String?>(fotosDepoisJson),
      'checkPergunta1': serializer.toJson<bool?>(checkPergunta1),
      'obsPergunta1': serializer.toJson<String?>(obsPergunta1),
      'checkPergunta2': serializer.toJson<bool?>(checkPergunta2),
      'obsPergunta2': serializer.toJson<String?>(obsPergunta2),
      'checkPergunta3': serializer.toJson<bool?>(checkPergunta3),
      'obsPergunta3': serializer.toJson<String?>(obsPergunta3),
      'checkPergunta4': serializer.toJson<bool?>(checkPergunta4),
      'obsPergunta4': serializer.toJson<String?>(obsPergunta4),
      'checkPergunta5': serializer.toJson<bool?>(checkPergunta5),
      'obsPergunta5': serializer.toJson<String?>(obsPergunta5),
      'checkPergunta6': serializer.toJson<bool?>(checkPergunta6),
      'obsPergunta6': serializer.toJson<String?>(obsPergunta6),
      'checkPergunta7': serializer.toJson<bool?>(checkPergunta7),
      'obsPergunta7': serializer.toJson<String?>(obsPergunta7),
      'comentariosVisita': serializer.toJson<String?>(comentariosVisita),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'syncedAt': serializer.toJson<String?>(syncedAt),
      'localState': serializer.toJson<String>(localState),
    };
  }

  Visita copyWith(
          {int? id,
          Value<int?> idPdvAssociado = const Value.absent(),
          Value<int?> idPromotorAssociado = const Value.absent(),
          Value<String?> diaHoraAgendado = const Value.absent(),
          Value<String?> diaHoraRealizado = const Value.absent(),
          Value<String?> diaHoraAbertura = const Value.absent(),
          Value<int?> statusVisita = const Value.absent(),
          Value<int?> rotaAssociada = const Value.absent(),
          Value<int?> idGabaritoAssociado = const Value.absent(),
          Value<String?> titulo = const Value.absent(),
          Value<String?> previsaoTurnoRealizada = const Value.absent(),
          Value<bool?> visitaAvulsa = const Value.absent(),
          Value<int?> serverId = const Value.absent(),
          Value<String?> localizacaoAbertura = const Value.absent(),
          Value<String?> localizacaoEncerramento = const Value.absent(),
          Value<String?> diaHoraFotosAntes = const Value.absent(),
          Value<String?> diaHoraFotosDepois = const Value.absent(),
          Value<String?> localizacaoFotosAntes = const Value.absent(),
          Value<String?> localizacaoFotosDepois = const Value.absent(),
          Value<String?> fotosAntesJson = const Value.absent(),
          Value<String?> fotosDepoisJson = const Value.absent(),
          Value<bool?> checkPergunta1 = const Value.absent(),
          Value<String?> obsPergunta1 = const Value.absent(),
          Value<bool?> checkPergunta2 = const Value.absent(),
          Value<String?> obsPergunta2 = const Value.absent(),
          Value<bool?> checkPergunta3 = const Value.absent(),
          Value<String?> obsPergunta3 = const Value.absent(),
          Value<bool?> checkPergunta4 = const Value.absent(),
          Value<String?> obsPergunta4 = const Value.absent(),
          Value<bool?> checkPergunta5 = const Value.absent(),
          Value<String?> obsPergunta5 = const Value.absent(),
          Value<bool?> checkPergunta6 = const Value.absent(),
          Value<String?> obsPergunta6 = const Value.absent(),
          Value<bool?> checkPergunta7 = const Value.absent(),
          Value<String?> obsPergunta7 = const Value.absent(),
          Value<String?> comentariosVisita = const Value.absent(),
          String? syncStatus,
          Value<String?> syncedAt = const Value.absent(),
          String? localState}) =>
      Visita(
        id: id ?? this.id,
        idPdvAssociado:
            idPdvAssociado.present ? idPdvAssociado.value : this.idPdvAssociado,
        idPromotorAssociado: idPromotorAssociado.present
            ? idPromotorAssociado.value
            : this.idPromotorAssociado,
        diaHoraAgendado: diaHoraAgendado.present
            ? diaHoraAgendado.value
            : this.diaHoraAgendado,
        diaHoraRealizado: diaHoraRealizado.present
            ? diaHoraRealizado.value
            : this.diaHoraRealizado,
        diaHoraAbertura: diaHoraAbertura.present
            ? diaHoraAbertura.value
            : this.diaHoraAbertura,
        statusVisita:
            statusVisita.present ? statusVisita.value : this.statusVisita,
        rotaAssociada:
            rotaAssociada.present ? rotaAssociada.value : this.rotaAssociada,
        idGabaritoAssociado: idGabaritoAssociado.present
            ? idGabaritoAssociado.value
            : this.idGabaritoAssociado,
        titulo: titulo.present ? titulo.value : this.titulo,
        previsaoTurnoRealizada: previsaoTurnoRealizada.present
            ? previsaoTurnoRealizada.value
            : this.previsaoTurnoRealizada,
        visitaAvulsa:
            visitaAvulsa.present ? visitaAvulsa.value : this.visitaAvulsa,
        serverId: serverId.present ? serverId.value : this.serverId,
        localizacaoAbertura: localizacaoAbertura.present
            ? localizacaoAbertura.value
            : this.localizacaoAbertura,
        localizacaoEncerramento: localizacaoEncerramento.present
            ? localizacaoEncerramento.value
            : this.localizacaoEncerramento,
        diaHoraFotosAntes: diaHoraFotosAntes.present
            ? diaHoraFotosAntes.value
            : this.diaHoraFotosAntes,
        diaHoraFotosDepois: diaHoraFotosDepois.present
            ? diaHoraFotosDepois.value
            : this.diaHoraFotosDepois,
        localizacaoFotosAntes: localizacaoFotosAntes.present
            ? localizacaoFotosAntes.value
            : this.localizacaoFotosAntes,
        localizacaoFotosDepois: localizacaoFotosDepois.present
            ? localizacaoFotosDepois.value
            : this.localizacaoFotosDepois,
        fotosAntesJson:
            fotosAntesJson.present ? fotosAntesJson.value : this.fotosAntesJson,
        fotosDepoisJson: fotosDepoisJson.present
            ? fotosDepoisJson.value
            : this.fotosDepoisJson,
        checkPergunta1:
            checkPergunta1.present ? checkPergunta1.value : this.checkPergunta1,
        obsPergunta1:
            obsPergunta1.present ? obsPergunta1.value : this.obsPergunta1,
        checkPergunta2:
            checkPergunta2.present ? checkPergunta2.value : this.checkPergunta2,
        obsPergunta2:
            obsPergunta2.present ? obsPergunta2.value : this.obsPergunta2,
        checkPergunta3:
            checkPergunta3.present ? checkPergunta3.value : this.checkPergunta3,
        obsPergunta3:
            obsPergunta3.present ? obsPergunta3.value : this.obsPergunta3,
        checkPergunta4:
            checkPergunta4.present ? checkPergunta4.value : this.checkPergunta4,
        obsPergunta4:
            obsPergunta4.present ? obsPergunta4.value : this.obsPergunta4,
        checkPergunta5:
            checkPergunta5.present ? checkPergunta5.value : this.checkPergunta5,
        obsPergunta5:
            obsPergunta5.present ? obsPergunta5.value : this.obsPergunta5,
        checkPergunta6:
            checkPergunta6.present ? checkPergunta6.value : this.checkPergunta6,
        obsPergunta6:
            obsPergunta6.present ? obsPergunta6.value : this.obsPergunta6,
        checkPergunta7:
            checkPergunta7.present ? checkPergunta7.value : this.checkPergunta7,
        obsPergunta7:
            obsPergunta7.present ? obsPergunta7.value : this.obsPergunta7,
        comentariosVisita: comentariosVisita.present
            ? comentariosVisita.value
            : this.comentariosVisita,
        syncStatus: syncStatus ?? this.syncStatus,
        syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
        localState: localState ?? this.localState,
      );
  Visita copyWithCompanion(VisitasCompanion data) {
    return Visita(
      id: data.id.present ? data.id.value : this.id,
      idPdvAssociado: data.idPdvAssociado.present
          ? data.idPdvAssociado.value
          : this.idPdvAssociado,
      idPromotorAssociado: data.idPromotorAssociado.present
          ? data.idPromotorAssociado.value
          : this.idPromotorAssociado,
      diaHoraAgendado: data.diaHoraAgendado.present
          ? data.diaHoraAgendado.value
          : this.diaHoraAgendado,
      diaHoraRealizado: data.diaHoraRealizado.present
          ? data.diaHoraRealizado.value
          : this.diaHoraRealizado,
      diaHoraAbertura: data.diaHoraAbertura.present
          ? data.diaHoraAbertura.value
          : this.diaHoraAbertura,
      statusVisita: data.statusVisita.present
          ? data.statusVisita.value
          : this.statusVisita,
      rotaAssociada: data.rotaAssociada.present
          ? data.rotaAssociada.value
          : this.rotaAssociada,
      idGabaritoAssociado: data.idGabaritoAssociado.present
          ? data.idGabaritoAssociado.value
          : this.idGabaritoAssociado,
      titulo: data.titulo.present ? data.titulo.value : this.titulo,
      previsaoTurnoRealizada: data.previsaoTurnoRealizada.present
          ? data.previsaoTurnoRealizada.value
          : this.previsaoTurnoRealizada,
      visitaAvulsa: data.visitaAvulsa.present
          ? data.visitaAvulsa.value
          : this.visitaAvulsa,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      localizacaoAbertura: data.localizacaoAbertura.present
          ? data.localizacaoAbertura.value
          : this.localizacaoAbertura,
      localizacaoEncerramento: data.localizacaoEncerramento.present
          ? data.localizacaoEncerramento.value
          : this.localizacaoEncerramento,
      diaHoraFotosAntes: data.diaHoraFotosAntes.present
          ? data.diaHoraFotosAntes.value
          : this.diaHoraFotosAntes,
      diaHoraFotosDepois: data.diaHoraFotosDepois.present
          ? data.diaHoraFotosDepois.value
          : this.diaHoraFotosDepois,
      localizacaoFotosAntes: data.localizacaoFotosAntes.present
          ? data.localizacaoFotosAntes.value
          : this.localizacaoFotosAntes,
      localizacaoFotosDepois: data.localizacaoFotosDepois.present
          ? data.localizacaoFotosDepois.value
          : this.localizacaoFotosDepois,
      fotosAntesJson: data.fotosAntesJson.present
          ? data.fotosAntesJson.value
          : this.fotosAntesJson,
      fotosDepoisJson: data.fotosDepoisJson.present
          ? data.fotosDepoisJson.value
          : this.fotosDepoisJson,
      checkPergunta1: data.checkPergunta1.present
          ? data.checkPergunta1.value
          : this.checkPergunta1,
      obsPergunta1: data.obsPergunta1.present
          ? data.obsPergunta1.value
          : this.obsPergunta1,
      checkPergunta2: data.checkPergunta2.present
          ? data.checkPergunta2.value
          : this.checkPergunta2,
      obsPergunta2: data.obsPergunta2.present
          ? data.obsPergunta2.value
          : this.obsPergunta2,
      checkPergunta3: data.checkPergunta3.present
          ? data.checkPergunta3.value
          : this.checkPergunta3,
      obsPergunta3: data.obsPergunta3.present
          ? data.obsPergunta3.value
          : this.obsPergunta3,
      checkPergunta4: data.checkPergunta4.present
          ? data.checkPergunta4.value
          : this.checkPergunta4,
      obsPergunta4: data.obsPergunta4.present
          ? data.obsPergunta4.value
          : this.obsPergunta4,
      checkPergunta5: data.checkPergunta5.present
          ? data.checkPergunta5.value
          : this.checkPergunta5,
      obsPergunta5: data.obsPergunta5.present
          ? data.obsPergunta5.value
          : this.obsPergunta5,
      checkPergunta6: data.checkPergunta6.present
          ? data.checkPergunta6.value
          : this.checkPergunta6,
      obsPergunta6: data.obsPergunta6.present
          ? data.obsPergunta6.value
          : this.obsPergunta6,
      checkPergunta7: data.checkPergunta7.present
          ? data.checkPergunta7.value
          : this.checkPergunta7,
      obsPergunta7: data.obsPergunta7.present
          ? data.obsPergunta7.value
          : this.obsPergunta7,
      comentariosVisita: data.comentariosVisita.present
          ? data.comentariosVisita.value
          : this.comentariosVisita,
      syncStatus:
          data.syncStatus.present ? data.syncStatus.value : this.syncStatus,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
      localState:
          data.localState.present ? data.localState.value : this.localState,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Visita(')
          ..write('id: $id, ')
          ..write('idPdvAssociado: $idPdvAssociado, ')
          ..write('idPromotorAssociado: $idPromotorAssociado, ')
          ..write('diaHoraAgendado: $diaHoraAgendado, ')
          ..write('diaHoraRealizado: $diaHoraRealizado, ')
          ..write('diaHoraAbertura: $diaHoraAbertura, ')
          ..write('statusVisita: $statusVisita, ')
          ..write('rotaAssociada: $rotaAssociada, ')
          ..write('idGabaritoAssociado: $idGabaritoAssociado, ')
          ..write('titulo: $titulo, ')
          ..write('previsaoTurnoRealizada: $previsaoTurnoRealizada, ')
          ..write('visitaAvulsa: $visitaAvulsa, ')
          ..write('serverId: $serverId, ')
          ..write('localizacaoAbertura: $localizacaoAbertura, ')
          ..write('localizacaoEncerramento: $localizacaoEncerramento, ')
          ..write('diaHoraFotosAntes: $diaHoraFotosAntes, ')
          ..write('diaHoraFotosDepois: $diaHoraFotosDepois, ')
          ..write('localizacaoFotosAntes: $localizacaoFotosAntes, ')
          ..write('localizacaoFotosDepois: $localizacaoFotosDepois, ')
          ..write('fotosAntesJson: $fotosAntesJson, ')
          ..write('fotosDepoisJson: $fotosDepoisJson, ')
          ..write('checkPergunta1: $checkPergunta1, ')
          ..write('obsPergunta1: $obsPergunta1, ')
          ..write('checkPergunta2: $checkPergunta2, ')
          ..write('obsPergunta2: $obsPergunta2, ')
          ..write('checkPergunta3: $checkPergunta3, ')
          ..write('obsPergunta3: $obsPergunta3, ')
          ..write('checkPergunta4: $checkPergunta4, ')
          ..write('obsPergunta4: $obsPergunta4, ')
          ..write('checkPergunta5: $checkPergunta5, ')
          ..write('obsPergunta5: $obsPergunta5, ')
          ..write('checkPergunta6: $checkPergunta6, ')
          ..write('obsPergunta6: $obsPergunta6, ')
          ..write('checkPergunta7: $checkPergunta7, ')
          ..write('obsPergunta7: $obsPergunta7, ')
          ..write('comentariosVisita: $comentariosVisita, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('localState: $localState')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
        id,
        idPdvAssociado,
        idPromotorAssociado,
        diaHoraAgendado,
        diaHoraRealizado,
        diaHoraAbertura,
        statusVisita,
        rotaAssociada,
        idGabaritoAssociado,
        titulo,
        previsaoTurnoRealizada,
        visitaAvulsa,
        serverId,
        localizacaoAbertura,
        localizacaoEncerramento,
        diaHoraFotosAntes,
        diaHoraFotosDepois,
        localizacaoFotosAntes,
        localizacaoFotosDepois,
        fotosAntesJson,
        fotosDepoisJson,
        checkPergunta1,
        obsPergunta1,
        checkPergunta2,
        obsPergunta2,
        checkPergunta3,
        obsPergunta3,
        checkPergunta4,
        obsPergunta4,
        checkPergunta5,
        obsPergunta5,
        checkPergunta6,
        obsPergunta6,
        checkPergunta7,
        obsPergunta7,
        comentariosVisita,
        syncStatus,
        syncedAt,
        localState
      ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Visita &&
          other.id == this.id &&
          other.idPdvAssociado == this.idPdvAssociado &&
          other.idPromotorAssociado == this.idPromotorAssociado &&
          other.diaHoraAgendado == this.diaHoraAgendado &&
          other.diaHoraRealizado == this.diaHoraRealizado &&
          other.diaHoraAbertura == this.diaHoraAbertura &&
          other.statusVisita == this.statusVisita &&
          other.rotaAssociada == this.rotaAssociada &&
          other.idGabaritoAssociado == this.idGabaritoAssociado &&
          other.titulo == this.titulo &&
          other.previsaoTurnoRealizada == this.previsaoTurnoRealizada &&
          other.visitaAvulsa == this.visitaAvulsa &&
          other.serverId == this.serverId &&
          other.localizacaoAbertura == this.localizacaoAbertura &&
          other.localizacaoEncerramento == this.localizacaoEncerramento &&
          other.diaHoraFotosAntes == this.diaHoraFotosAntes &&
          other.diaHoraFotosDepois == this.diaHoraFotosDepois &&
          other.localizacaoFotosAntes == this.localizacaoFotosAntes &&
          other.localizacaoFotosDepois == this.localizacaoFotosDepois &&
          other.fotosAntesJson == this.fotosAntesJson &&
          other.fotosDepoisJson == this.fotosDepoisJson &&
          other.checkPergunta1 == this.checkPergunta1 &&
          other.obsPergunta1 == this.obsPergunta1 &&
          other.checkPergunta2 == this.checkPergunta2 &&
          other.obsPergunta2 == this.obsPergunta2 &&
          other.checkPergunta3 == this.checkPergunta3 &&
          other.obsPergunta3 == this.obsPergunta3 &&
          other.checkPergunta4 == this.checkPergunta4 &&
          other.obsPergunta4 == this.obsPergunta4 &&
          other.checkPergunta5 == this.checkPergunta5 &&
          other.obsPergunta5 == this.obsPergunta5 &&
          other.checkPergunta6 == this.checkPergunta6 &&
          other.obsPergunta6 == this.obsPergunta6 &&
          other.checkPergunta7 == this.checkPergunta7 &&
          other.obsPergunta7 == this.obsPergunta7 &&
          other.comentariosVisita == this.comentariosVisita &&
          other.syncStatus == this.syncStatus &&
          other.syncedAt == this.syncedAt &&
          other.localState == this.localState);
}

class VisitasCompanion extends UpdateCompanion<Visita> {
  final Value<int> id;
  final Value<int?> idPdvAssociado;
  final Value<int?> idPromotorAssociado;
  final Value<String?> diaHoraAgendado;
  final Value<String?> diaHoraRealizado;
  final Value<String?> diaHoraAbertura;
  final Value<int?> statusVisita;
  final Value<int?> rotaAssociada;
  final Value<int?> idGabaritoAssociado;
  final Value<String?> titulo;
  final Value<String?> previsaoTurnoRealizada;
  final Value<bool?> visitaAvulsa;
  final Value<int?> serverId;
  final Value<String?> localizacaoAbertura;
  final Value<String?> localizacaoEncerramento;
  final Value<String?> diaHoraFotosAntes;
  final Value<String?> diaHoraFotosDepois;
  final Value<String?> localizacaoFotosAntes;
  final Value<String?> localizacaoFotosDepois;
  final Value<String?> fotosAntesJson;
  final Value<String?> fotosDepoisJson;
  final Value<bool?> checkPergunta1;
  final Value<String?> obsPergunta1;
  final Value<bool?> checkPergunta2;
  final Value<String?> obsPergunta2;
  final Value<bool?> checkPergunta3;
  final Value<String?> obsPergunta3;
  final Value<bool?> checkPergunta4;
  final Value<String?> obsPergunta4;
  final Value<bool?> checkPergunta5;
  final Value<String?> obsPergunta5;
  final Value<bool?> checkPergunta6;
  final Value<String?> obsPergunta6;
  final Value<bool?> checkPergunta7;
  final Value<String?> obsPergunta7;
  final Value<String?> comentariosVisita;
  final Value<String> syncStatus;
  final Value<String?> syncedAt;
  final Value<String> localState;
  const VisitasCompanion({
    this.id = const Value.absent(),
    this.idPdvAssociado = const Value.absent(),
    this.idPromotorAssociado = const Value.absent(),
    this.diaHoraAgendado = const Value.absent(),
    this.diaHoraRealizado = const Value.absent(),
    this.diaHoraAbertura = const Value.absent(),
    this.statusVisita = const Value.absent(),
    this.rotaAssociada = const Value.absent(),
    this.idGabaritoAssociado = const Value.absent(),
    this.titulo = const Value.absent(),
    this.previsaoTurnoRealizada = const Value.absent(),
    this.visitaAvulsa = const Value.absent(),
    this.serverId = const Value.absent(),
    this.localizacaoAbertura = const Value.absent(),
    this.localizacaoEncerramento = const Value.absent(),
    this.diaHoraFotosAntes = const Value.absent(),
    this.diaHoraFotosDepois = const Value.absent(),
    this.localizacaoFotosAntes = const Value.absent(),
    this.localizacaoFotosDepois = const Value.absent(),
    this.fotosAntesJson = const Value.absent(),
    this.fotosDepoisJson = const Value.absent(),
    this.checkPergunta1 = const Value.absent(),
    this.obsPergunta1 = const Value.absent(),
    this.checkPergunta2 = const Value.absent(),
    this.obsPergunta2 = const Value.absent(),
    this.checkPergunta3 = const Value.absent(),
    this.obsPergunta3 = const Value.absent(),
    this.checkPergunta4 = const Value.absent(),
    this.obsPergunta4 = const Value.absent(),
    this.checkPergunta5 = const Value.absent(),
    this.obsPergunta5 = const Value.absent(),
    this.checkPergunta6 = const Value.absent(),
    this.obsPergunta6 = const Value.absent(),
    this.checkPergunta7 = const Value.absent(),
    this.obsPergunta7 = const Value.absent(),
    this.comentariosVisita = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.localState = const Value.absent(),
  });
  VisitasCompanion.insert({
    this.id = const Value.absent(),
    this.idPdvAssociado = const Value.absent(),
    this.idPromotorAssociado = const Value.absent(),
    this.diaHoraAgendado = const Value.absent(),
    this.diaHoraRealizado = const Value.absent(),
    this.diaHoraAbertura = const Value.absent(),
    this.statusVisita = const Value.absent(),
    this.rotaAssociada = const Value.absent(),
    this.idGabaritoAssociado = const Value.absent(),
    this.titulo = const Value.absent(),
    this.previsaoTurnoRealizada = const Value.absent(),
    this.visitaAvulsa = const Value.absent(),
    this.serverId = const Value.absent(),
    this.localizacaoAbertura = const Value.absent(),
    this.localizacaoEncerramento = const Value.absent(),
    this.diaHoraFotosAntes = const Value.absent(),
    this.diaHoraFotosDepois = const Value.absent(),
    this.localizacaoFotosAntes = const Value.absent(),
    this.localizacaoFotosDepois = const Value.absent(),
    this.fotosAntesJson = const Value.absent(),
    this.fotosDepoisJson = const Value.absent(),
    this.checkPergunta1 = const Value.absent(),
    this.obsPergunta1 = const Value.absent(),
    this.checkPergunta2 = const Value.absent(),
    this.obsPergunta2 = const Value.absent(),
    this.checkPergunta3 = const Value.absent(),
    this.obsPergunta3 = const Value.absent(),
    this.checkPergunta4 = const Value.absent(),
    this.obsPergunta4 = const Value.absent(),
    this.checkPergunta5 = const Value.absent(),
    this.obsPergunta5 = const Value.absent(),
    this.checkPergunta6 = const Value.absent(),
    this.obsPergunta6 = const Value.absent(),
    this.checkPergunta7 = const Value.absent(),
    this.obsPergunta7 = const Value.absent(),
    this.comentariosVisita = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.localState = const Value.absent(),
  });
  static Insertable<Visita> custom({
    Expression<int>? id,
    Expression<int>? idPdvAssociado,
    Expression<int>? idPromotorAssociado,
    Expression<String>? diaHoraAgendado,
    Expression<String>? diaHoraRealizado,
    Expression<String>? diaHoraAbertura,
    Expression<int>? statusVisita,
    Expression<int>? rotaAssociada,
    Expression<int>? idGabaritoAssociado,
    Expression<String>? titulo,
    Expression<String>? previsaoTurnoRealizada,
    Expression<bool>? visitaAvulsa,
    Expression<int>? serverId,
    Expression<String>? localizacaoAbertura,
    Expression<String>? localizacaoEncerramento,
    Expression<String>? diaHoraFotosAntes,
    Expression<String>? diaHoraFotosDepois,
    Expression<String>? localizacaoFotosAntes,
    Expression<String>? localizacaoFotosDepois,
    Expression<String>? fotosAntesJson,
    Expression<String>? fotosDepoisJson,
    Expression<bool>? checkPergunta1,
    Expression<String>? obsPergunta1,
    Expression<bool>? checkPergunta2,
    Expression<String>? obsPergunta2,
    Expression<bool>? checkPergunta3,
    Expression<String>? obsPergunta3,
    Expression<bool>? checkPergunta4,
    Expression<String>? obsPergunta4,
    Expression<bool>? checkPergunta5,
    Expression<String>? obsPergunta5,
    Expression<bool>? checkPergunta6,
    Expression<String>? obsPergunta6,
    Expression<bool>? checkPergunta7,
    Expression<String>? obsPergunta7,
    Expression<String>? comentariosVisita,
    Expression<String>? syncStatus,
    Expression<String>? syncedAt,
    Expression<String>? localState,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (idPdvAssociado != null) 'id_pdv_associado': idPdvAssociado,
      if (idPromotorAssociado != null)
        'id_promotor_associado': idPromotorAssociado,
      if (diaHoraAgendado != null) 'dia_hora_agendado': diaHoraAgendado,
      if (diaHoraRealizado != null) 'dia_hora_realizado': diaHoraRealizado,
      if (diaHoraAbertura != null) 'dia_hora_abertura': diaHoraAbertura,
      if (statusVisita != null) 'status_visita': statusVisita,
      if (rotaAssociada != null) 'rota_associada': rotaAssociada,
      if (idGabaritoAssociado != null)
        'id_gabarito_associado': idGabaritoAssociado,
      if (titulo != null) 'titulo': titulo,
      if (previsaoTurnoRealizada != null)
        'previsao_turno_realizada': previsaoTurnoRealizada,
      if (visitaAvulsa != null) 'visita_avulsa': visitaAvulsa,
      if (serverId != null) 'server_id': serverId,
      if (localizacaoAbertura != null)
        'localizacao_abertura': localizacaoAbertura,
      if (localizacaoEncerramento != null)
        'localizacao_encerramento': localizacaoEncerramento,
      if (diaHoraFotosAntes != null) 'dia_hora_fotos_antes': diaHoraFotosAntes,
      if (diaHoraFotosDepois != null)
        'dia_hora_fotos_depois': diaHoraFotosDepois,
      if (localizacaoFotosAntes != null)
        'localizacao_fotos_antes': localizacaoFotosAntes,
      if (localizacaoFotosDepois != null)
        'localizacao_fotos_depois': localizacaoFotosDepois,
      if (fotosAntesJson != null) 'fotos_antes_json': fotosAntesJson,
      if (fotosDepoisJson != null) 'fotos_depois_json': fotosDepoisJson,
      if (checkPergunta1 != null) 'check_pergunta1': checkPergunta1,
      if (obsPergunta1 != null) 'obs_pergunta1': obsPergunta1,
      if (checkPergunta2 != null) 'check_pergunta2': checkPergunta2,
      if (obsPergunta2 != null) 'obs_pergunta2': obsPergunta2,
      if (checkPergunta3 != null) 'check_pergunta3': checkPergunta3,
      if (obsPergunta3 != null) 'obs_pergunta3': obsPergunta3,
      if (checkPergunta4 != null) 'check_pergunta4': checkPergunta4,
      if (obsPergunta4 != null) 'obs_pergunta4': obsPergunta4,
      if (checkPergunta5 != null) 'check_pergunta5': checkPergunta5,
      if (obsPergunta5 != null) 'obs_pergunta5': obsPergunta5,
      if (checkPergunta6 != null) 'check_pergunta6': checkPergunta6,
      if (obsPergunta6 != null) 'obs_pergunta6': obsPergunta6,
      if (checkPergunta7 != null) 'check_pergunta7': checkPergunta7,
      if (obsPergunta7 != null) 'obs_pergunta7': obsPergunta7,
      if (comentariosVisita != null) 'comentarios_visita': comentariosVisita,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (localState != null) 'local_state': localState,
    });
  }

  VisitasCompanion copyWith(
      {Value<int>? id,
      Value<int?>? idPdvAssociado,
      Value<int?>? idPromotorAssociado,
      Value<String?>? diaHoraAgendado,
      Value<String?>? diaHoraRealizado,
      Value<String?>? diaHoraAbertura,
      Value<int?>? statusVisita,
      Value<int?>? rotaAssociada,
      Value<int?>? idGabaritoAssociado,
      Value<String?>? titulo,
      Value<String?>? previsaoTurnoRealizada,
      Value<bool?>? visitaAvulsa,
      Value<int?>? serverId,
      Value<String?>? localizacaoAbertura,
      Value<String?>? localizacaoEncerramento,
      Value<String?>? diaHoraFotosAntes,
      Value<String?>? diaHoraFotosDepois,
      Value<String?>? localizacaoFotosAntes,
      Value<String?>? localizacaoFotosDepois,
      Value<String?>? fotosAntesJson,
      Value<String?>? fotosDepoisJson,
      Value<bool?>? checkPergunta1,
      Value<String?>? obsPergunta1,
      Value<bool?>? checkPergunta2,
      Value<String?>? obsPergunta2,
      Value<bool?>? checkPergunta3,
      Value<String?>? obsPergunta3,
      Value<bool?>? checkPergunta4,
      Value<String?>? obsPergunta4,
      Value<bool?>? checkPergunta5,
      Value<String?>? obsPergunta5,
      Value<bool?>? checkPergunta6,
      Value<String?>? obsPergunta6,
      Value<bool?>? checkPergunta7,
      Value<String?>? obsPergunta7,
      Value<String?>? comentariosVisita,
      Value<String>? syncStatus,
      Value<String?>? syncedAt,
      Value<String>? localState}) {
    return VisitasCompanion(
      id: id ?? this.id,
      idPdvAssociado: idPdvAssociado ?? this.idPdvAssociado,
      idPromotorAssociado: idPromotorAssociado ?? this.idPromotorAssociado,
      diaHoraAgendado: diaHoraAgendado ?? this.diaHoraAgendado,
      diaHoraRealizado: diaHoraRealizado ?? this.diaHoraRealizado,
      diaHoraAbertura: diaHoraAbertura ?? this.diaHoraAbertura,
      statusVisita: statusVisita ?? this.statusVisita,
      rotaAssociada: rotaAssociada ?? this.rotaAssociada,
      idGabaritoAssociado: idGabaritoAssociado ?? this.idGabaritoAssociado,
      titulo: titulo ?? this.titulo,
      previsaoTurnoRealizada:
          previsaoTurnoRealizada ?? this.previsaoTurnoRealizada,
      visitaAvulsa: visitaAvulsa ?? this.visitaAvulsa,
      serverId: serverId ?? this.serverId,
      localizacaoAbertura: localizacaoAbertura ?? this.localizacaoAbertura,
      localizacaoEncerramento:
          localizacaoEncerramento ?? this.localizacaoEncerramento,
      diaHoraFotosAntes: diaHoraFotosAntes ?? this.diaHoraFotosAntes,
      diaHoraFotosDepois: diaHoraFotosDepois ?? this.diaHoraFotosDepois,
      localizacaoFotosAntes:
          localizacaoFotosAntes ?? this.localizacaoFotosAntes,
      localizacaoFotosDepois:
          localizacaoFotosDepois ?? this.localizacaoFotosDepois,
      fotosAntesJson: fotosAntesJson ?? this.fotosAntesJson,
      fotosDepoisJson: fotosDepoisJson ?? this.fotosDepoisJson,
      checkPergunta1: checkPergunta1 ?? this.checkPergunta1,
      obsPergunta1: obsPergunta1 ?? this.obsPergunta1,
      checkPergunta2: checkPergunta2 ?? this.checkPergunta2,
      obsPergunta2: obsPergunta2 ?? this.obsPergunta2,
      checkPergunta3: checkPergunta3 ?? this.checkPergunta3,
      obsPergunta3: obsPergunta3 ?? this.obsPergunta3,
      checkPergunta4: checkPergunta4 ?? this.checkPergunta4,
      obsPergunta4: obsPergunta4 ?? this.obsPergunta4,
      checkPergunta5: checkPergunta5 ?? this.checkPergunta5,
      obsPergunta5: obsPergunta5 ?? this.obsPergunta5,
      checkPergunta6: checkPergunta6 ?? this.checkPergunta6,
      obsPergunta6: obsPergunta6 ?? this.obsPergunta6,
      checkPergunta7: checkPergunta7 ?? this.checkPergunta7,
      obsPergunta7: obsPergunta7 ?? this.obsPergunta7,
      comentariosVisita: comentariosVisita ?? this.comentariosVisita,
      syncStatus: syncStatus ?? this.syncStatus,
      syncedAt: syncedAt ?? this.syncedAt,
      localState: localState ?? this.localState,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (idPdvAssociado.present) {
      map['id_pdv_associado'] = Variable<int>(idPdvAssociado.value);
    }
    if (idPromotorAssociado.present) {
      map['id_promotor_associado'] = Variable<int>(idPromotorAssociado.value);
    }
    if (diaHoraAgendado.present) {
      map['dia_hora_agendado'] = Variable<String>(diaHoraAgendado.value);
    }
    if (diaHoraRealizado.present) {
      map['dia_hora_realizado'] = Variable<String>(diaHoraRealizado.value);
    }
    if (diaHoraAbertura.present) {
      map['dia_hora_abertura'] = Variable<String>(diaHoraAbertura.value);
    }
    if (statusVisita.present) {
      map['status_visita'] = Variable<int>(statusVisita.value);
    }
    if (rotaAssociada.present) {
      map['rota_associada'] = Variable<int>(rotaAssociada.value);
    }
    if (idGabaritoAssociado.present) {
      map['id_gabarito_associado'] = Variable<int>(idGabaritoAssociado.value);
    }
    if (titulo.present) {
      map['titulo'] = Variable<String>(titulo.value);
    }
    if (previsaoTurnoRealizada.present) {
      map['previsao_turno_realizada'] =
          Variable<String>(previsaoTurnoRealizada.value);
    }
    if (visitaAvulsa.present) {
      map['visita_avulsa'] = Variable<bool>(visitaAvulsa.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<int>(serverId.value);
    }
    if (localizacaoAbertura.present) {
      map['localizacao_abertura'] = Variable<String>(localizacaoAbertura.value);
    }
    if (localizacaoEncerramento.present) {
      map['localizacao_encerramento'] =
          Variable<String>(localizacaoEncerramento.value);
    }
    if (diaHoraFotosAntes.present) {
      map['dia_hora_fotos_antes'] = Variable<String>(diaHoraFotosAntes.value);
    }
    if (diaHoraFotosDepois.present) {
      map['dia_hora_fotos_depois'] = Variable<String>(diaHoraFotosDepois.value);
    }
    if (localizacaoFotosAntes.present) {
      map['localizacao_fotos_antes'] =
          Variable<String>(localizacaoFotosAntes.value);
    }
    if (localizacaoFotosDepois.present) {
      map['localizacao_fotos_depois'] =
          Variable<String>(localizacaoFotosDepois.value);
    }
    if (fotosAntesJson.present) {
      map['fotos_antes_json'] = Variable<String>(fotosAntesJson.value);
    }
    if (fotosDepoisJson.present) {
      map['fotos_depois_json'] = Variable<String>(fotosDepoisJson.value);
    }
    if (checkPergunta1.present) {
      map['check_pergunta1'] = Variable<bool>(checkPergunta1.value);
    }
    if (obsPergunta1.present) {
      map['obs_pergunta1'] = Variable<String>(obsPergunta1.value);
    }
    if (checkPergunta2.present) {
      map['check_pergunta2'] = Variable<bool>(checkPergunta2.value);
    }
    if (obsPergunta2.present) {
      map['obs_pergunta2'] = Variable<String>(obsPergunta2.value);
    }
    if (checkPergunta3.present) {
      map['check_pergunta3'] = Variable<bool>(checkPergunta3.value);
    }
    if (obsPergunta3.present) {
      map['obs_pergunta3'] = Variable<String>(obsPergunta3.value);
    }
    if (checkPergunta4.present) {
      map['check_pergunta4'] = Variable<bool>(checkPergunta4.value);
    }
    if (obsPergunta4.present) {
      map['obs_pergunta4'] = Variable<String>(obsPergunta4.value);
    }
    if (checkPergunta5.present) {
      map['check_pergunta5'] = Variable<bool>(checkPergunta5.value);
    }
    if (obsPergunta5.present) {
      map['obs_pergunta5'] = Variable<String>(obsPergunta5.value);
    }
    if (checkPergunta6.present) {
      map['check_pergunta6'] = Variable<bool>(checkPergunta6.value);
    }
    if (obsPergunta6.present) {
      map['obs_pergunta6'] = Variable<String>(obsPergunta6.value);
    }
    if (checkPergunta7.present) {
      map['check_pergunta7'] = Variable<bool>(checkPergunta7.value);
    }
    if (obsPergunta7.present) {
      map['obs_pergunta7'] = Variable<String>(obsPergunta7.value);
    }
    if (comentariosVisita.present) {
      map['comentarios_visita'] = Variable<String>(comentariosVisita.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<String>(syncedAt.value);
    }
    if (localState.present) {
      map['local_state'] = Variable<String>(localState.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VisitasCompanion(')
          ..write('id: $id, ')
          ..write('idPdvAssociado: $idPdvAssociado, ')
          ..write('idPromotorAssociado: $idPromotorAssociado, ')
          ..write('diaHoraAgendado: $diaHoraAgendado, ')
          ..write('diaHoraRealizado: $diaHoraRealizado, ')
          ..write('diaHoraAbertura: $diaHoraAbertura, ')
          ..write('statusVisita: $statusVisita, ')
          ..write('rotaAssociada: $rotaAssociada, ')
          ..write('idGabaritoAssociado: $idGabaritoAssociado, ')
          ..write('titulo: $titulo, ')
          ..write('previsaoTurnoRealizada: $previsaoTurnoRealizada, ')
          ..write('visitaAvulsa: $visitaAvulsa, ')
          ..write('serverId: $serverId, ')
          ..write('localizacaoAbertura: $localizacaoAbertura, ')
          ..write('localizacaoEncerramento: $localizacaoEncerramento, ')
          ..write('diaHoraFotosAntes: $diaHoraFotosAntes, ')
          ..write('diaHoraFotosDepois: $diaHoraFotosDepois, ')
          ..write('localizacaoFotosAntes: $localizacaoFotosAntes, ')
          ..write('localizacaoFotosDepois: $localizacaoFotosDepois, ')
          ..write('fotosAntesJson: $fotosAntesJson, ')
          ..write('fotosDepoisJson: $fotosDepoisJson, ')
          ..write('checkPergunta1: $checkPergunta1, ')
          ..write('obsPergunta1: $obsPergunta1, ')
          ..write('checkPergunta2: $checkPergunta2, ')
          ..write('obsPergunta2: $obsPergunta2, ')
          ..write('checkPergunta3: $checkPergunta3, ')
          ..write('obsPergunta3: $obsPergunta3, ')
          ..write('checkPergunta4: $checkPergunta4, ')
          ..write('obsPergunta4: $obsPergunta4, ')
          ..write('checkPergunta5: $checkPergunta5, ')
          ..write('obsPergunta5: $obsPergunta5, ')
          ..write('checkPergunta6: $checkPergunta6, ')
          ..write('obsPergunta6: $obsPergunta6, ')
          ..write('checkPergunta7: $checkPergunta7, ')
          ..write('obsPergunta7: $obsPergunta7, ')
          ..write('comentariosVisita: $comentariosVisita, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('localState: $localState')
          ..write(')'))
        .toString();
  }
}

class $OutboxItemsTable extends OutboxItems
    with TableInfo<$OutboxItemsTable, OutboxItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _entityTypeMeta =
      const VerificationMeta('entityType');
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
      'entity_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _operationMeta =
      const VerificationMeta('operation');
  @override
  late final GeneratedColumn<String> operation = GeneratedColumn<String>(
      'operation', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _entityIdMeta =
      const VerificationMeta('entityId');
  @override
  late final GeneratedColumn<int> entityId = GeneratedColumn<int>(
      'entity_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _payloadJsonMeta =
      const VerificationMeta('payloadJson');
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
      'payload_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _attemptsMeta =
      const VerificationMeta('attempts');
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
      'attempts', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _nextRetryAtMeta =
      const VerificationMeta('nextRetryAt');
  @override
  late final GeneratedColumn<String> nextRetryAt = GeneratedColumn<String>(
      'next_retry_at', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _lastErrorMeta =
      const VerificationMeta('lastError');
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
      'last_error', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('pending'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
      'created_at', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        entityType,
        operation,
        entityId,
        payloadJson,
        attempts,
        nextRetryAt,
        lastError,
        status,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox_items';
  @override
  VerificationContext validateIntegrity(Insertable<OutboxItem> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
          _entityTypeMeta,
          entityType.isAcceptableOrUnknown(
              data['entity_type']!, _entityTypeMeta));
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('operation')) {
      context.handle(_operationMeta,
          operation.isAcceptableOrUnknown(data['operation']!, _operationMeta));
    } else if (isInserting) {
      context.missing(_operationMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(_entityIdMeta,
          entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta));
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
          _payloadJsonMeta,
          payloadJson.isAcceptableOrUnknown(
              data['payload_json']!, _payloadJsonMeta));
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(_attemptsMeta,
          attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta));
    }
    if (data.containsKey('next_retry_at')) {
      context.handle(
          _nextRetryAtMeta,
          nextRetryAt.isAcceptableOrUnknown(
              data['next_retry_at']!, _nextRetryAtMeta));
    } else if (isInserting) {
      context.missing(_nextRetryAtMeta);
    }
    if (data.containsKey('last_error')) {
      context.handle(_lastErrorMeta,
          lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OutboxItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxItem(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      entityType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}entity_type'])!,
      operation: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}operation'])!,
      entityId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}entity_id'])!,
      payloadJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload_json'])!,
      attempts: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}attempts'])!,
      nextRetryAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}next_retry_at'])!,
      lastError: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}last_error']),
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $OutboxItemsTable createAlias(String alias) {
    return $OutboxItemsTable(attachedDatabase, alias);
  }
}

class OutboxItem extends DataClass implements Insertable<OutboxItem> {
  final String id;
  final String entityType;
  final String operation;
  final int entityId;
  final String payloadJson;
  final int attempts;
  final String nextRetryAt;
  final String? lastError;
  final String status;
  final String createdAt;
  const OutboxItem(
      {required this.id,
      required this.entityType,
      required this.operation,
      required this.entityId,
      required this.payloadJson,
      required this.attempts,
      required this.nextRetryAt,
      this.lastError,
      required this.status,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['entity_type'] = Variable<String>(entityType);
    map['operation'] = Variable<String>(operation);
    map['entity_id'] = Variable<int>(entityId);
    map['payload_json'] = Variable<String>(payloadJson);
    map['attempts'] = Variable<int>(attempts);
    map['next_retry_at'] = Variable<String>(nextRetryAt);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<String>(createdAt);
    return map;
  }

  OutboxItemsCompanion toCompanion(bool nullToAbsent) {
    return OutboxItemsCompanion(
      id: Value(id),
      entityType: Value(entityType),
      operation: Value(operation),
      entityId: Value(entityId),
      payloadJson: Value(payloadJson),
      attempts: Value(attempts),
      nextRetryAt: Value(nextRetryAt),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      status: Value(status),
      createdAt: Value(createdAt),
    );
  }

  factory OutboxItem.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxItem(
      id: serializer.fromJson<String>(json['id']),
      entityType: serializer.fromJson<String>(json['entityType']),
      operation: serializer.fromJson<String>(json['operation']),
      entityId: serializer.fromJson<int>(json['entityId']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      attempts: serializer.fromJson<int>(json['attempts']),
      nextRetryAt: serializer.fromJson<String>(json['nextRetryAt']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'entityType': serializer.toJson<String>(entityType),
      'operation': serializer.toJson<String>(operation),
      'entityId': serializer.toJson<int>(entityId),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'attempts': serializer.toJson<int>(attempts),
      'nextRetryAt': serializer.toJson<String>(nextRetryAt),
      'lastError': serializer.toJson<String?>(lastError),
      'status': serializer.toJson<String>(status),
      'createdAt': serializer.toJson<String>(createdAt),
    };
  }

  OutboxItem copyWith(
          {String? id,
          String? entityType,
          String? operation,
          int? entityId,
          String? payloadJson,
          int? attempts,
          String? nextRetryAt,
          Value<String?> lastError = const Value.absent(),
          String? status,
          String? createdAt}) =>
      OutboxItem(
        id: id ?? this.id,
        entityType: entityType ?? this.entityType,
        operation: operation ?? this.operation,
        entityId: entityId ?? this.entityId,
        payloadJson: payloadJson ?? this.payloadJson,
        attempts: attempts ?? this.attempts,
        nextRetryAt: nextRetryAt ?? this.nextRetryAt,
        lastError: lastError.present ? lastError.value : this.lastError,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
      );
  OutboxItem copyWithCompanion(OutboxItemsCompanion data) {
    return OutboxItem(
      id: data.id.present ? data.id.value : this.id,
      entityType:
          data.entityType.present ? data.entityType.value : this.entityType,
      operation: data.operation.present ? data.operation.value : this.operation,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      payloadJson:
          data.payloadJson.present ? data.payloadJson.value : this.payloadJson,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      nextRetryAt:
          data.nextRetryAt.present ? data.nextRetryAt.value : this.nextRetryAt,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxItem(')
          ..write('id: $id, ')
          ..write('entityType: $entityType, ')
          ..write('operation: $operation, ')
          ..write('entityId: $entityId, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('attempts: $attempts, ')
          ..write('nextRetryAt: $nextRetryAt, ')
          ..write('lastError: $lastError, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, entityType, operation, entityId,
      payloadJson, attempts, nextRetryAt, lastError, status, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxItem &&
          other.id == this.id &&
          other.entityType == this.entityType &&
          other.operation == this.operation &&
          other.entityId == this.entityId &&
          other.payloadJson == this.payloadJson &&
          other.attempts == this.attempts &&
          other.nextRetryAt == this.nextRetryAt &&
          other.lastError == this.lastError &&
          other.status == this.status &&
          other.createdAt == this.createdAt);
}

class OutboxItemsCompanion extends UpdateCompanion<OutboxItem> {
  final Value<String> id;
  final Value<String> entityType;
  final Value<String> operation;
  final Value<int> entityId;
  final Value<String> payloadJson;
  final Value<int> attempts;
  final Value<String> nextRetryAt;
  final Value<String?> lastError;
  final Value<String> status;
  final Value<String> createdAt;
  final Value<int> rowid;
  const OutboxItemsCompanion({
    this.id = const Value.absent(),
    this.entityType = const Value.absent(),
    this.operation = const Value.absent(),
    this.entityId = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.attempts = const Value.absent(),
    this.nextRetryAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OutboxItemsCompanion.insert({
    required String id,
    required String entityType,
    required String operation,
    required int entityId,
    required String payloadJson,
    this.attempts = const Value.absent(),
    required String nextRetryAt,
    this.lastError = const Value.absent(),
    this.status = const Value.absent(),
    required String createdAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        entityType = Value(entityType),
        operation = Value(operation),
        entityId = Value(entityId),
        payloadJson = Value(payloadJson),
        nextRetryAt = Value(nextRetryAt),
        createdAt = Value(createdAt);
  static Insertable<OutboxItem> custom({
    Expression<String>? id,
    Expression<String>? entityType,
    Expression<String>? operation,
    Expression<int>? entityId,
    Expression<String>? payloadJson,
    Expression<int>? attempts,
    Expression<String>? nextRetryAt,
    Expression<String>? lastError,
    Expression<String>? status,
    Expression<String>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entityType != null) 'entity_type': entityType,
      if (operation != null) 'operation': operation,
      if (entityId != null) 'entity_id': entityId,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (attempts != null) 'attempts': attempts,
      if (nextRetryAt != null) 'next_retry_at': nextRetryAt,
      if (lastError != null) 'last_error': lastError,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OutboxItemsCompanion copyWith(
      {Value<String>? id,
      Value<String>? entityType,
      Value<String>? operation,
      Value<int>? entityId,
      Value<String>? payloadJson,
      Value<int>? attempts,
      Value<String>? nextRetryAt,
      Value<String?>? lastError,
      Value<String>? status,
      Value<String>? createdAt,
      Value<int>? rowid}) {
    return OutboxItemsCompanion(
      id: id ?? this.id,
      entityType: entityType ?? this.entityType,
      operation: operation ?? this.operation,
      entityId: entityId ?? this.entityId,
      payloadJson: payloadJson ?? this.payloadJson,
      attempts: attempts ?? this.attempts,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
      lastError: lastError ?? this.lastError,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (operation.present) {
      map['operation'] = Variable<String>(operation.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<int>(entityId.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (nextRetryAt.present) {
      map['next_retry_at'] = Variable<String>(nextRetryAt.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxItemsCompanion(')
          ..write('id: $id, ')
          ..write('entityType: $entityType, ')
          ..write('operation: $operation, ')
          ..write('entityId: $entityId, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('attempts: $attempts, ')
          ..write('nextRetryAt: $nextRetryAt, ')
          ..write('lastError: $lastError, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendingPhotosTable extends PendingPhotos
    with TableInfo<$PendingPhotosTable, PendingPhoto> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingPhotosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _visitaIdMeta =
      const VerificationMeta('visitaId');
  @override
  late final GeneratedColumn<int> visitaId = GeneratedColumn<int>(
      'visita_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _slotMeta = const VerificationMeta('slot');
  @override
  late final GeneratedColumn<String> slot = GeneratedColumn<String>(
      'slot', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _numeroMeta = const VerificationMeta('numero');
  @override
  late final GeneratedColumn<int> numero = GeneratedColumn<int>(
      'numero', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _localPathMeta =
      const VerificationMeta('localPath');
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
      'local_path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('pending'));
  static const VerificationMeta _storageUrlMeta =
      const VerificationMeta('storageUrl');
  @override
  late final GeneratedColumn<String> storageUrl = GeneratedColumn<String>(
      'storage_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _attemptsMeta =
      const VerificationMeta('attempts');
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
      'attempts', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _nextRetryAtMeta =
      const VerificationMeta('nextRetryAt');
  @override
  late final GeneratedColumn<String> nextRetryAt = GeneratedColumn<String>(
      'next_retry_at', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
      'created_at', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        visitaId,
        slot,
        numero,
        localPath,
        status,
        storageUrl,
        attempts,
        nextRetryAt,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_photos';
  @override
  VerificationContext validateIntegrity(Insertable<PendingPhoto> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('visita_id')) {
      context.handle(_visitaIdMeta,
          visitaId.isAcceptableOrUnknown(data['visita_id']!, _visitaIdMeta));
    } else if (isInserting) {
      context.missing(_visitaIdMeta);
    }
    if (data.containsKey('slot')) {
      context.handle(
          _slotMeta, slot.isAcceptableOrUnknown(data['slot']!, _slotMeta));
    } else if (isInserting) {
      context.missing(_slotMeta);
    }
    if (data.containsKey('numero')) {
      context.handle(_numeroMeta,
          numero.isAcceptableOrUnknown(data['numero']!, _numeroMeta));
    } else if (isInserting) {
      context.missing(_numeroMeta);
    }
    if (data.containsKey('local_path')) {
      context.handle(_localPathMeta,
          localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta));
    } else if (isInserting) {
      context.missing(_localPathMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('storage_url')) {
      context.handle(
          _storageUrlMeta,
          storageUrl.isAcceptableOrUnknown(
              data['storage_url']!, _storageUrlMeta));
    }
    if (data.containsKey('attempts')) {
      context.handle(_attemptsMeta,
          attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta));
    }
    if (data.containsKey('next_retry_at')) {
      context.handle(
          _nextRetryAtMeta,
          nextRetryAt.isAcceptableOrUnknown(
              data['next_retry_at']!, _nextRetryAtMeta));
    } else if (isInserting) {
      context.missing(_nextRetryAtMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PendingPhoto map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingPhoto(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      visitaId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}visita_id'])!,
      slot: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}slot'])!,
      numero: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}numero'])!,
      localPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}local_path'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      storageUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}storage_url']),
      attempts: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}attempts'])!,
      nextRetryAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}next_retry_at'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $PendingPhotosTable createAlias(String alias) {
    return $PendingPhotosTable(attachedDatabase, alias);
  }
}

class PendingPhoto extends DataClass implements Insertable<PendingPhoto> {
  final String id;
  final int visitaId;
  final String slot;
  final int numero;
  final String localPath;
  final String status;
  final String? storageUrl;
  final int attempts;
  final String nextRetryAt;
  final String createdAt;
  const PendingPhoto(
      {required this.id,
      required this.visitaId,
      required this.slot,
      required this.numero,
      required this.localPath,
      required this.status,
      this.storageUrl,
      required this.attempts,
      required this.nextRetryAt,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['visita_id'] = Variable<int>(visitaId);
    map['slot'] = Variable<String>(slot);
    map['numero'] = Variable<int>(numero);
    map['local_path'] = Variable<String>(localPath);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || storageUrl != null) {
      map['storage_url'] = Variable<String>(storageUrl);
    }
    map['attempts'] = Variable<int>(attempts);
    map['next_retry_at'] = Variable<String>(nextRetryAt);
    map['created_at'] = Variable<String>(createdAt);
    return map;
  }

  PendingPhotosCompanion toCompanion(bool nullToAbsent) {
    return PendingPhotosCompanion(
      id: Value(id),
      visitaId: Value(visitaId),
      slot: Value(slot),
      numero: Value(numero),
      localPath: Value(localPath),
      status: Value(status),
      storageUrl: storageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(storageUrl),
      attempts: Value(attempts),
      nextRetryAt: Value(nextRetryAt),
      createdAt: Value(createdAt),
    );
  }

  factory PendingPhoto.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingPhoto(
      id: serializer.fromJson<String>(json['id']),
      visitaId: serializer.fromJson<int>(json['visitaId']),
      slot: serializer.fromJson<String>(json['slot']),
      numero: serializer.fromJson<int>(json['numero']),
      localPath: serializer.fromJson<String>(json['localPath']),
      status: serializer.fromJson<String>(json['status']),
      storageUrl: serializer.fromJson<String?>(json['storageUrl']),
      attempts: serializer.fromJson<int>(json['attempts']),
      nextRetryAt: serializer.fromJson<String>(json['nextRetryAt']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'visitaId': serializer.toJson<int>(visitaId),
      'slot': serializer.toJson<String>(slot),
      'numero': serializer.toJson<int>(numero),
      'localPath': serializer.toJson<String>(localPath),
      'status': serializer.toJson<String>(status),
      'storageUrl': serializer.toJson<String?>(storageUrl),
      'attempts': serializer.toJson<int>(attempts),
      'nextRetryAt': serializer.toJson<String>(nextRetryAt),
      'createdAt': serializer.toJson<String>(createdAt),
    };
  }

  PendingPhoto copyWith(
          {String? id,
          int? visitaId,
          String? slot,
          int? numero,
          String? localPath,
          String? status,
          Value<String?> storageUrl = const Value.absent(),
          int? attempts,
          String? nextRetryAt,
          String? createdAt}) =>
      PendingPhoto(
        id: id ?? this.id,
        visitaId: visitaId ?? this.visitaId,
        slot: slot ?? this.slot,
        numero: numero ?? this.numero,
        localPath: localPath ?? this.localPath,
        status: status ?? this.status,
        storageUrl: storageUrl.present ? storageUrl.value : this.storageUrl,
        attempts: attempts ?? this.attempts,
        nextRetryAt: nextRetryAt ?? this.nextRetryAt,
        createdAt: createdAt ?? this.createdAt,
      );
  PendingPhoto copyWithCompanion(PendingPhotosCompanion data) {
    return PendingPhoto(
      id: data.id.present ? data.id.value : this.id,
      visitaId: data.visitaId.present ? data.visitaId.value : this.visitaId,
      slot: data.slot.present ? data.slot.value : this.slot,
      numero: data.numero.present ? data.numero.value : this.numero,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      status: data.status.present ? data.status.value : this.status,
      storageUrl:
          data.storageUrl.present ? data.storageUrl.value : this.storageUrl,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      nextRetryAt:
          data.nextRetryAt.present ? data.nextRetryAt.value : this.nextRetryAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingPhoto(')
          ..write('id: $id, ')
          ..write('visitaId: $visitaId, ')
          ..write('slot: $slot, ')
          ..write('numero: $numero, ')
          ..write('localPath: $localPath, ')
          ..write('status: $status, ')
          ..write('storageUrl: $storageUrl, ')
          ..write('attempts: $attempts, ')
          ..write('nextRetryAt: $nextRetryAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, visitaId, slot, numero, localPath, status,
      storageUrl, attempts, nextRetryAt, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingPhoto &&
          other.id == this.id &&
          other.visitaId == this.visitaId &&
          other.slot == this.slot &&
          other.numero == this.numero &&
          other.localPath == this.localPath &&
          other.status == this.status &&
          other.storageUrl == this.storageUrl &&
          other.attempts == this.attempts &&
          other.nextRetryAt == this.nextRetryAt &&
          other.createdAt == this.createdAt);
}

class PendingPhotosCompanion extends UpdateCompanion<PendingPhoto> {
  final Value<String> id;
  final Value<int> visitaId;
  final Value<String> slot;
  final Value<int> numero;
  final Value<String> localPath;
  final Value<String> status;
  final Value<String?> storageUrl;
  final Value<int> attempts;
  final Value<String> nextRetryAt;
  final Value<String> createdAt;
  final Value<int> rowid;
  const PendingPhotosCompanion({
    this.id = const Value.absent(),
    this.visitaId = const Value.absent(),
    this.slot = const Value.absent(),
    this.numero = const Value.absent(),
    this.localPath = const Value.absent(),
    this.status = const Value.absent(),
    this.storageUrl = const Value.absent(),
    this.attempts = const Value.absent(),
    this.nextRetryAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PendingPhotosCompanion.insert({
    required String id,
    required int visitaId,
    required String slot,
    required int numero,
    required String localPath,
    this.status = const Value.absent(),
    this.storageUrl = const Value.absent(),
    this.attempts = const Value.absent(),
    required String nextRetryAt,
    required String createdAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        visitaId = Value(visitaId),
        slot = Value(slot),
        numero = Value(numero),
        localPath = Value(localPath),
        nextRetryAt = Value(nextRetryAt),
        createdAt = Value(createdAt);
  static Insertable<PendingPhoto> custom({
    Expression<String>? id,
    Expression<int>? visitaId,
    Expression<String>? slot,
    Expression<int>? numero,
    Expression<String>? localPath,
    Expression<String>? status,
    Expression<String>? storageUrl,
    Expression<int>? attempts,
    Expression<String>? nextRetryAt,
    Expression<String>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (visitaId != null) 'visita_id': visitaId,
      if (slot != null) 'slot': slot,
      if (numero != null) 'numero': numero,
      if (localPath != null) 'local_path': localPath,
      if (status != null) 'status': status,
      if (storageUrl != null) 'storage_url': storageUrl,
      if (attempts != null) 'attempts': attempts,
      if (nextRetryAt != null) 'next_retry_at': nextRetryAt,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PendingPhotosCompanion copyWith(
      {Value<String>? id,
      Value<int>? visitaId,
      Value<String>? slot,
      Value<int>? numero,
      Value<String>? localPath,
      Value<String>? status,
      Value<String?>? storageUrl,
      Value<int>? attempts,
      Value<String>? nextRetryAt,
      Value<String>? createdAt,
      Value<int>? rowid}) {
    return PendingPhotosCompanion(
      id: id ?? this.id,
      visitaId: visitaId ?? this.visitaId,
      slot: slot ?? this.slot,
      numero: numero ?? this.numero,
      localPath: localPath ?? this.localPath,
      status: status ?? this.status,
      storageUrl: storageUrl ?? this.storageUrl,
      attempts: attempts ?? this.attempts,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (visitaId.present) {
      map['visita_id'] = Variable<int>(visitaId.value);
    }
    if (slot.present) {
      map['slot'] = Variable<String>(slot.value);
    }
    if (numero.present) {
      map['numero'] = Variable<int>(numero.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (storageUrl.present) {
      map['storage_url'] = Variable<String>(storageUrl.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (nextRetryAt.present) {
      map['next_retry_at'] = Variable<String>(nextRetryAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingPhotosCompanion(')
          ..write('id: $id, ')
          ..write('visitaId: $visitaId, ')
          ..write('slot: $slot, ')
          ..write('numero: $numero, ')
          ..write('localPath: $localPath, ')
          ..write('status: $status, ')
          ..write('storageUrl: $storageUrl, ')
          ..write('attempts: $attempts, ')
          ..write('nextRetryAt: $nextRetryAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncStateTable extends SyncState
    with TableInfo<$SyncStateTable, SyncStateData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncStateTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _entityTypeMeta =
      const VerificationMeta('entityType');
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
      'entity_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _lastPullAtMeta =
      const VerificationMeta('lastPullAt');
  @override
  late final GeneratedColumn<String> lastPullAt = GeneratedColumn<String>(
      'last_pull_at', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _lastPushAtMeta =
      const VerificationMeta('lastPushAt');
  @override
  late final GeneratedColumn<String> lastPushAt = GeneratedColumn<String>(
      'last_push_at', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [entityType, lastPullAt, lastPushAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_state';
  @override
  VerificationContext validateIntegrity(Insertable<SyncStateData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('entity_type')) {
      context.handle(
          _entityTypeMeta,
          entityType.isAcceptableOrUnknown(
              data['entity_type']!, _entityTypeMeta));
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('last_pull_at')) {
      context.handle(
          _lastPullAtMeta,
          lastPullAt.isAcceptableOrUnknown(
              data['last_pull_at']!, _lastPullAtMeta));
    }
    if (data.containsKey('last_push_at')) {
      context.handle(
          _lastPushAtMeta,
          lastPushAt.isAcceptableOrUnknown(
              data['last_push_at']!, _lastPushAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {entityType};
  @override
  SyncStateData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncStateData(
      entityType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}entity_type'])!,
      lastPullAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}last_pull_at']),
      lastPushAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}last_push_at']),
    );
  }

  @override
  $SyncStateTable createAlias(String alias) {
    return $SyncStateTable(attachedDatabase, alias);
  }
}

class SyncStateData extends DataClass implements Insertable<SyncStateData> {
  final String entityType;
  final String? lastPullAt;
  final String? lastPushAt;
  const SyncStateData(
      {required this.entityType, this.lastPullAt, this.lastPushAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['entity_type'] = Variable<String>(entityType);
    if (!nullToAbsent || lastPullAt != null) {
      map['last_pull_at'] = Variable<String>(lastPullAt);
    }
    if (!nullToAbsent || lastPushAt != null) {
      map['last_push_at'] = Variable<String>(lastPushAt);
    }
    return map;
  }

  SyncStateCompanion toCompanion(bool nullToAbsent) {
    return SyncStateCompanion(
      entityType: Value(entityType),
      lastPullAt: lastPullAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPullAt),
      lastPushAt: lastPushAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPushAt),
    );
  }

  factory SyncStateData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncStateData(
      entityType: serializer.fromJson<String>(json['entityType']),
      lastPullAt: serializer.fromJson<String?>(json['lastPullAt']),
      lastPushAt: serializer.fromJson<String?>(json['lastPushAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'entityType': serializer.toJson<String>(entityType),
      'lastPullAt': serializer.toJson<String?>(lastPullAt),
      'lastPushAt': serializer.toJson<String?>(lastPushAt),
    };
  }

  SyncStateData copyWith(
          {String? entityType,
          Value<String?> lastPullAt = const Value.absent(),
          Value<String?> lastPushAt = const Value.absent()}) =>
      SyncStateData(
        entityType: entityType ?? this.entityType,
        lastPullAt: lastPullAt.present ? lastPullAt.value : this.lastPullAt,
        lastPushAt: lastPushAt.present ? lastPushAt.value : this.lastPushAt,
      );
  SyncStateData copyWithCompanion(SyncStateCompanion data) {
    return SyncStateData(
      entityType:
          data.entityType.present ? data.entityType.value : this.entityType,
      lastPullAt:
          data.lastPullAt.present ? data.lastPullAt.value : this.lastPullAt,
      lastPushAt:
          data.lastPushAt.present ? data.lastPushAt.value : this.lastPushAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateData(')
          ..write('entityType: $entityType, ')
          ..write('lastPullAt: $lastPullAt, ')
          ..write('lastPushAt: $lastPushAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(entityType, lastPullAt, lastPushAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncStateData &&
          other.entityType == this.entityType &&
          other.lastPullAt == this.lastPullAt &&
          other.lastPushAt == this.lastPushAt);
}

class SyncStateCompanion extends UpdateCompanion<SyncStateData> {
  final Value<String> entityType;
  final Value<String?> lastPullAt;
  final Value<String?> lastPushAt;
  final Value<int> rowid;
  const SyncStateCompanion({
    this.entityType = const Value.absent(),
    this.lastPullAt = const Value.absent(),
    this.lastPushAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncStateCompanion.insert({
    required String entityType,
    this.lastPullAt = const Value.absent(),
    this.lastPushAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : entityType = Value(entityType);
  static Insertable<SyncStateData> custom({
    Expression<String>? entityType,
    Expression<String>? lastPullAt,
    Expression<String>? lastPushAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (entityType != null) 'entity_type': entityType,
      if (lastPullAt != null) 'last_pull_at': lastPullAt,
      if (lastPushAt != null) 'last_push_at': lastPushAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncStateCompanion copyWith(
      {Value<String>? entityType,
      Value<String?>? lastPullAt,
      Value<String?>? lastPushAt,
      Value<int>? rowid}) {
    return SyncStateCompanion(
      entityType: entityType ?? this.entityType,
      lastPullAt: lastPullAt ?? this.lastPullAt,
      lastPushAt: lastPushAt ?? this.lastPushAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (lastPullAt.present) {
      map['last_pull_at'] = Variable<String>(lastPullAt.value);
    }
    if (lastPushAt.present) {
      map['last_push_at'] = Variable<String>(lastPushAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateCompanion(')
          ..write('entityType: $entityType, ')
          ..write('lastPullAt: $lastPullAt, ')
          ..write('lastPushAt: $lastPushAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $UsersTable users = $UsersTable(this);
  late final $PdvsTable pdvs = $PdvsTable(this);
  late final $GabaritosTable gabaritos = $GabaritosTable(this);
  late final $VisitasTable visitas = $VisitasTable(this);
  late final $OutboxItemsTable outboxItems = $OutboxItemsTable(this);
  late final $PendingPhotosTable pendingPhotos = $PendingPhotosTable(this);
  late final $SyncStateTable syncState = $SyncStateTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [users, pdvs, gabaritos, visitas, outboxItems, pendingPhotos, syncState];
}

typedef $$UsersTableCreateCompanionBuilder = UsersCompanion Function({
  Value<int> id,
  Value<String?> nome,
  Value<String?> email,
  Value<String?> foto,
  Value<int?> tipoUser,
  Value<bool> ativo,
  Value<String?> areaAtuacao,
  Value<String?> telefone,
  Value<String?> syncedAt,
});
typedef $$UsersTableUpdateCompanionBuilder = UsersCompanion Function({
  Value<int> id,
  Value<String?> nome,
  Value<String?> email,
  Value<String?> foto,
  Value<int?> tipoUser,
  Value<bool> ativo,
  Value<String?> areaAtuacao,
  Value<String?> telefone,
  Value<String?> syncedAt,
});

class $$UsersTableFilterComposer extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get nome => $composableBuilder(
      column: $table.nome, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get email => $composableBuilder(
      column: $table.email, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get foto => $composableBuilder(
      column: $table.foto, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get tipoUser => $composableBuilder(
      column: $table.tipoUser, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get ativo => $composableBuilder(
      column: $table.ativo, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get areaAtuacao => $composableBuilder(
      column: $table.areaAtuacao, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get telefone => $composableBuilder(
      column: $table.telefone, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnFilters(column));
}

class $$UsersTableOrderingComposer
    extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get nome => $composableBuilder(
      column: $table.nome, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get email => $composableBuilder(
      column: $table.email, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get foto => $composableBuilder(
      column: $table.foto, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get tipoUser => $composableBuilder(
      column: $table.tipoUser, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get ativo => $composableBuilder(
      column: $table.ativo, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get areaAtuacao => $composableBuilder(
      column: $table.areaAtuacao, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get telefone => $composableBuilder(
      column: $table.telefone, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnOrderings(column));
}

class $$UsersTableAnnotationComposer
    extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get nome =>
      $composableBuilder(column: $table.nome, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get foto =>
      $composableBuilder(column: $table.foto, builder: (column) => column);

  GeneratedColumn<int> get tipoUser =>
      $composableBuilder(column: $table.tipoUser, builder: (column) => column);

  GeneratedColumn<bool> get ativo =>
      $composableBuilder(column: $table.ativo, builder: (column) => column);

  GeneratedColumn<String> get areaAtuacao => $composableBuilder(
      column: $table.areaAtuacao, builder: (column) => column);

  GeneratedColumn<String> get telefone =>
      $composableBuilder(column: $table.telefone, builder: (column) => column);

  GeneratedColumn<String> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$UsersTableTableManager extends RootTableManager<
    _$AppDatabase,
    $UsersTable,
    User,
    $$UsersTableFilterComposer,
    $$UsersTableOrderingComposer,
    $$UsersTableAnnotationComposer,
    $$UsersTableCreateCompanionBuilder,
    $$UsersTableUpdateCompanionBuilder,
    (User, BaseReferences<_$AppDatabase, $UsersTable, User>),
    User,
    PrefetchHooks Function()> {
  $$UsersTableTableManager(_$AppDatabase db, $UsersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UsersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UsersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UsersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String?> nome = const Value.absent(),
            Value<String?> email = const Value.absent(),
            Value<String?> foto = const Value.absent(),
            Value<int?> tipoUser = const Value.absent(),
            Value<bool> ativo = const Value.absent(),
            Value<String?> areaAtuacao = const Value.absent(),
            Value<String?> telefone = const Value.absent(),
            Value<String?> syncedAt = const Value.absent(),
          }) =>
              UsersCompanion(
            id: id,
            nome: nome,
            email: email,
            foto: foto,
            tipoUser: tipoUser,
            ativo: ativo,
            areaAtuacao: areaAtuacao,
            telefone: telefone,
            syncedAt: syncedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String?> nome = const Value.absent(),
            Value<String?> email = const Value.absent(),
            Value<String?> foto = const Value.absent(),
            Value<int?> tipoUser = const Value.absent(),
            Value<bool> ativo = const Value.absent(),
            Value<String?> areaAtuacao = const Value.absent(),
            Value<String?> telefone = const Value.absent(),
            Value<String?> syncedAt = const Value.absent(),
          }) =>
              UsersCompanion.insert(
            id: id,
            nome: nome,
            email: email,
            foto: foto,
            tipoUser: tipoUser,
            ativo: ativo,
            areaAtuacao: areaAtuacao,
            telefone: telefone,
            syncedAt: syncedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$UsersTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $UsersTable,
    User,
    $$UsersTableFilterComposer,
    $$UsersTableOrderingComposer,
    $$UsersTableAnnotationComposer,
    $$UsersTableCreateCompanionBuilder,
    $$UsersTableUpdateCompanionBuilder,
    (User, BaseReferences<_$AppDatabase, $UsersTable, User>),
    User,
    PrefetchHooks Function()>;
typedef $$PdvsTableCreateCompanionBuilder = PdvsCompanion Function({
  Value<int> id,
  Value<String?> apiLocalName,
  Value<String?> apiLocalCustomerName,
  Value<String?> endereco,
  Value<String?> apiSpecificLocation,
  Value<double?> lat,
  Value<double?> lng,
  Value<bool?> situacao,
  Value<String?> syncedAt,
});
typedef $$PdvsTableUpdateCompanionBuilder = PdvsCompanion Function({
  Value<int> id,
  Value<String?> apiLocalName,
  Value<String?> apiLocalCustomerName,
  Value<String?> endereco,
  Value<String?> apiSpecificLocation,
  Value<double?> lat,
  Value<double?> lng,
  Value<bool?> situacao,
  Value<String?> syncedAt,
});

class $$PdvsTableFilterComposer extends Composer<_$AppDatabase, $PdvsTable> {
  $$PdvsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get apiLocalName => $composableBuilder(
      column: $table.apiLocalName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get apiLocalCustomerName => $composableBuilder(
      column: $table.apiLocalCustomerName,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get endereco => $composableBuilder(
      column: $table.endereco, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get apiSpecificLocation => $composableBuilder(
      column: $table.apiSpecificLocation,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get lat => $composableBuilder(
      column: $table.lat, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get lng => $composableBuilder(
      column: $table.lng, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get situacao => $composableBuilder(
      column: $table.situacao, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnFilters(column));
}

class $$PdvsTableOrderingComposer extends Composer<_$AppDatabase, $PdvsTable> {
  $$PdvsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get apiLocalName => $composableBuilder(
      column: $table.apiLocalName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get apiLocalCustomerName => $composableBuilder(
      column: $table.apiLocalCustomerName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get endereco => $composableBuilder(
      column: $table.endereco, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get apiSpecificLocation => $composableBuilder(
      column: $table.apiSpecificLocation,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get lat => $composableBuilder(
      column: $table.lat, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get lng => $composableBuilder(
      column: $table.lng, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get situacao => $composableBuilder(
      column: $table.situacao, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnOrderings(column));
}

class $$PdvsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PdvsTable> {
  $$PdvsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get apiLocalName => $composableBuilder(
      column: $table.apiLocalName, builder: (column) => column);

  GeneratedColumn<String> get apiLocalCustomerName => $composableBuilder(
      column: $table.apiLocalCustomerName, builder: (column) => column);

  GeneratedColumn<String> get endereco =>
      $composableBuilder(column: $table.endereco, builder: (column) => column);

  GeneratedColumn<String> get apiSpecificLocation => $composableBuilder(
      column: $table.apiSpecificLocation, builder: (column) => column);

  GeneratedColumn<double> get lat =>
      $composableBuilder(column: $table.lat, builder: (column) => column);

  GeneratedColumn<double> get lng =>
      $composableBuilder(column: $table.lng, builder: (column) => column);

  GeneratedColumn<bool> get situacao =>
      $composableBuilder(column: $table.situacao, builder: (column) => column);

  GeneratedColumn<String> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$PdvsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PdvsTable,
    Pdv,
    $$PdvsTableFilterComposer,
    $$PdvsTableOrderingComposer,
    $$PdvsTableAnnotationComposer,
    $$PdvsTableCreateCompanionBuilder,
    $$PdvsTableUpdateCompanionBuilder,
    (Pdv, BaseReferences<_$AppDatabase, $PdvsTable, Pdv>),
    Pdv,
    PrefetchHooks Function()> {
  $$PdvsTableTableManager(_$AppDatabase db, $PdvsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PdvsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PdvsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PdvsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String?> apiLocalName = const Value.absent(),
            Value<String?> apiLocalCustomerName = const Value.absent(),
            Value<String?> endereco = const Value.absent(),
            Value<String?> apiSpecificLocation = const Value.absent(),
            Value<double?> lat = const Value.absent(),
            Value<double?> lng = const Value.absent(),
            Value<bool?> situacao = const Value.absent(),
            Value<String?> syncedAt = const Value.absent(),
          }) =>
              PdvsCompanion(
            id: id,
            apiLocalName: apiLocalName,
            apiLocalCustomerName: apiLocalCustomerName,
            endereco: endereco,
            apiSpecificLocation: apiSpecificLocation,
            lat: lat,
            lng: lng,
            situacao: situacao,
            syncedAt: syncedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String?> apiLocalName = const Value.absent(),
            Value<String?> apiLocalCustomerName = const Value.absent(),
            Value<String?> endereco = const Value.absent(),
            Value<String?> apiSpecificLocation = const Value.absent(),
            Value<double?> lat = const Value.absent(),
            Value<double?> lng = const Value.absent(),
            Value<bool?> situacao = const Value.absent(),
            Value<String?> syncedAt = const Value.absent(),
          }) =>
              PdvsCompanion.insert(
            id: id,
            apiLocalName: apiLocalName,
            apiLocalCustomerName: apiLocalCustomerName,
            endereco: endereco,
            apiSpecificLocation: apiSpecificLocation,
            lat: lat,
            lng: lng,
            situacao: situacao,
            syncedAt: syncedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PdvsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PdvsTable,
    Pdv,
    $$PdvsTableFilterComposer,
    $$PdvsTableOrderingComposer,
    $$PdvsTableAnnotationComposer,
    $$PdvsTableCreateCompanionBuilder,
    $$PdvsTableUpdateCompanionBuilder,
    (Pdv, BaseReferences<_$AppDatabase, $PdvsTable, Pdv>),
    Pdv,
    PrefetchHooks Function()>;
typedef $$GabaritosTableCreateCompanionBuilder = GabaritosCompanion Function({
  Value<int> id,
  Value<String?> nome,
  required int pdvAssociado,
  Value<int?> rotaAssociada,
  Value<int?> promotorAssociado,
  Value<bool> ativo,
  Value<bool> padrao,
  Value<String?> prazoValidade,
  Value<String?> syncedAt,
});
typedef $$GabaritosTableUpdateCompanionBuilder = GabaritosCompanion Function({
  Value<int> id,
  Value<String?> nome,
  Value<int> pdvAssociado,
  Value<int?> rotaAssociada,
  Value<int?> promotorAssociado,
  Value<bool> ativo,
  Value<bool> padrao,
  Value<String?> prazoValidade,
  Value<String?> syncedAt,
});

class $$GabaritosTableFilterComposer
    extends Composer<_$AppDatabase, $GabaritosTable> {
  $$GabaritosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get nome => $composableBuilder(
      column: $table.nome, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get pdvAssociado => $composableBuilder(
      column: $table.pdvAssociado, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get rotaAssociada => $composableBuilder(
      column: $table.rotaAssociada, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get promotorAssociado => $composableBuilder(
      column: $table.promotorAssociado,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get ativo => $composableBuilder(
      column: $table.ativo, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get padrao => $composableBuilder(
      column: $table.padrao, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get prazoValidade => $composableBuilder(
      column: $table.prazoValidade, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnFilters(column));
}

class $$GabaritosTableOrderingComposer
    extends Composer<_$AppDatabase, $GabaritosTable> {
  $$GabaritosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get nome => $composableBuilder(
      column: $table.nome, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get pdvAssociado => $composableBuilder(
      column: $table.pdvAssociado,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get rotaAssociada => $composableBuilder(
      column: $table.rotaAssociada,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get promotorAssociado => $composableBuilder(
      column: $table.promotorAssociado,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get ativo => $composableBuilder(
      column: $table.ativo, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get padrao => $composableBuilder(
      column: $table.padrao, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get prazoValidade => $composableBuilder(
      column: $table.prazoValidade,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnOrderings(column));
}

class $$GabaritosTableAnnotationComposer
    extends Composer<_$AppDatabase, $GabaritosTable> {
  $$GabaritosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get nome =>
      $composableBuilder(column: $table.nome, builder: (column) => column);

  GeneratedColumn<int> get pdvAssociado => $composableBuilder(
      column: $table.pdvAssociado, builder: (column) => column);

  GeneratedColumn<int> get rotaAssociada => $composableBuilder(
      column: $table.rotaAssociada, builder: (column) => column);

  GeneratedColumn<int> get promotorAssociado => $composableBuilder(
      column: $table.promotorAssociado, builder: (column) => column);

  GeneratedColumn<bool> get ativo =>
      $composableBuilder(column: $table.ativo, builder: (column) => column);

  GeneratedColumn<bool> get padrao =>
      $composableBuilder(column: $table.padrao, builder: (column) => column);

  GeneratedColumn<String> get prazoValidade => $composableBuilder(
      column: $table.prazoValidade, builder: (column) => column);

  GeneratedColumn<String> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$GabaritosTableTableManager extends RootTableManager<
    _$AppDatabase,
    $GabaritosTable,
    Gabarito,
    $$GabaritosTableFilterComposer,
    $$GabaritosTableOrderingComposer,
    $$GabaritosTableAnnotationComposer,
    $$GabaritosTableCreateCompanionBuilder,
    $$GabaritosTableUpdateCompanionBuilder,
    (Gabarito, BaseReferences<_$AppDatabase, $GabaritosTable, Gabarito>),
    Gabarito,
    PrefetchHooks Function()> {
  $$GabaritosTableTableManager(_$AppDatabase db, $GabaritosTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GabaritosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GabaritosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GabaritosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String?> nome = const Value.absent(),
            Value<int> pdvAssociado = const Value.absent(),
            Value<int?> rotaAssociada = const Value.absent(),
            Value<int?> promotorAssociado = const Value.absent(),
            Value<bool> ativo = const Value.absent(),
            Value<bool> padrao = const Value.absent(),
            Value<String?> prazoValidade = const Value.absent(),
            Value<String?> syncedAt = const Value.absent(),
          }) =>
              GabaritosCompanion(
            id: id,
            nome: nome,
            pdvAssociado: pdvAssociado,
            rotaAssociada: rotaAssociada,
            promotorAssociado: promotorAssociado,
            ativo: ativo,
            padrao: padrao,
            prazoValidade: prazoValidade,
            syncedAt: syncedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String?> nome = const Value.absent(),
            required int pdvAssociado,
            Value<int?> rotaAssociada = const Value.absent(),
            Value<int?> promotorAssociado = const Value.absent(),
            Value<bool> ativo = const Value.absent(),
            Value<bool> padrao = const Value.absent(),
            Value<String?> prazoValidade = const Value.absent(),
            Value<String?> syncedAt = const Value.absent(),
          }) =>
              GabaritosCompanion.insert(
            id: id,
            nome: nome,
            pdvAssociado: pdvAssociado,
            rotaAssociada: rotaAssociada,
            promotorAssociado: promotorAssociado,
            ativo: ativo,
            padrao: padrao,
            prazoValidade: prazoValidade,
            syncedAt: syncedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$GabaritosTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $GabaritosTable,
    Gabarito,
    $$GabaritosTableFilterComposer,
    $$GabaritosTableOrderingComposer,
    $$GabaritosTableAnnotationComposer,
    $$GabaritosTableCreateCompanionBuilder,
    $$GabaritosTableUpdateCompanionBuilder,
    (Gabarito, BaseReferences<_$AppDatabase, $GabaritosTable, Gabarito>),
    Gabarito,
    PrefetchHooks Function()>;
typedef $$VisitasTableCreateCompanionBuilder = VisitasCompanion Function({
  Value<int> id,
  Value<int?> idPdvAssociado,
  Value<int?> idPromotorAssociado,
  Value<String?> diaHoraAgendado,
  Value<String?> diaHoraRealizado,
  Value<String?> diaHoraAbertura,
  Value<int?> statusVisita,
  Value<int?> rotaAssociada,
  Value<int?> idGabaritoAssociado,
  Value<String?> titulo,
  Value<String?> previsaoTurnoRealizada,
  Value<bool?> visitaAvulsa,
  Value<int?> serverId,
  Value<String?> localizacaoAbertura,
  Value<String?> localizacaoEncerramento,
  Value<String?> diaHoraFotosAntes,
  Value<String?> diaHoraFotosDepois,
  Value<String?> localizacaoFotosAntes,
  Value<String?> localizacaoFotosDepois,
  Value<String?> fotosAntesJson,
  Value<String?> fotosDepoisJson,
  Value<bool?> checkPergunta1,
  Value<String?> obsPergunta1,
  Value<bool?> checkPergunta2,
  Value<String?> obsPergunta2,
  Value<bool?> checkPergunta3,
  Value<String?> obsPergunta3,
  Value<bool?> checkPergunta4,
  Value<String?> obsPergunta4,
  Value<bool?> checkPergunta5,
  Value<String?> obsPergunta5,
  Value<bool?> checkPergunta6,
  Value<String?> obsPergunta6,
  Value<bool?> checkPergunta7,
  Value<String?> obsPergunta7,
  Value<String?> comentariosVisita,
  Value<String> syncStatus,
  Value<String?> syncedAt,
  Value<String> localState,
});
typedef $$VisitasTableUpdateCompanionBuilder = VisitasCompanion Function({
  Value<int> id,
  Value<int?> idPdvAssociado,
  Value<int?> idPromotorAssociado,
  Value<String?> diaHoraAgendado,
  Value<String?> diaHoraRealizado,
  Value<String?> diaHoraAbertura,
  Value<int?> statusVisita,
  Value<int?> rotaAssociada,
  Value<int?> idGabaritoAssociado,
  Value<String?> titulo,
  Value<String?> previsaoTurnoRealizada,
  Value<bool?> visitaAvulsa,
  Value<int?> serverId,
  Value<String?> localizacaoAbertura,
  Value<String?> localizacaoEncerramento,
  Value<String?> diaHoraFotosAntes,
  Value<String?> diaHoraFotosDepois,
  Value<String?> localizacaoFotosAntes,
  Value<String?> localizacaoFotosDepois,
  Value<String?> fotosAntesJson,
  Value<String?> fotosDepoisJson,
  Value<bool?> checkPergunta1,
  Value<String?> obsPergunta1,
  Value<bool?> checkPergunta2,
  Value<String?> obsPergunta2,
  Value<bool?> checkPergunta3,
  Value<String?> obsPergunta3,
  Value<bool?> checkPergunta4,
  Value<String?> obsPergunta4,
  Value<bool?> checkPergunta5,
  Value<String?> obsPergunta5,
  Value<bool?> checkPergunta6,
  Value<String?> obsPergunta6,
  Value<bool?> checkPergunta7,
  Value<String?> obsPergunta7,
  Value<String?> comentariosVisita,
  Value<String> syncStatus,
  Value<String?> syncedAt,
  Value<String> localState,
});

class $$VisitasTableFilterComposer
    extends Composer<_$AppDatabase, $VisitasTable> {
  $$VisitasTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get idPdvAssociado => $composableBuilder(
      column: $table.idPdvAssociado,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get idPromotorAssociado => $composableBuilder(
      column: $table.idPromotorAssociado,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get diaHoraAgendado => $composableBuilder(
      column: $table.diaHoraAgendado,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get diaHoraRealizado => $composableBuilder(
      column: $table.diaHoraRealizado,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get diaHoraAbertura => $composableBuilder(
      column: $table.diaHoraAbertura,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get statusVisita => $composableBuilder(
      column: $table.statusVisita, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get rotaAssociada => $composableBuilder(
      column: $table.rotaAssociada, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get idGabaritoAssociado => $composableBuilder(
      column: $table.idGabaritoAssociado,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get titulo => $composableBuilder(
      column: $table.titulo, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get previsaoTurnoRealizada => $composableBuilder(
      column: $table.previsaoTurnoRealizada,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get visitaAvulsa => $composableBuilder(
      column: $table.visitaAvulsa, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get serverId => $composableBuilder(
      column: $table.serverId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get localizacaoAbertura => $composableBuilder(
      column: $table.localizacaoAbertura,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get localizacaoEncerramento => $composableBuilder(
      column: $table.localizacaoEncerramento,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get diaHoraFotosAntes => $composableBuilder(
      column: $table.diaHoraFotosAntes,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get diaHoraFotosDepois => $composableBuilder(
      column: $table.diaHoraFotosDepois,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get localizacaoFotosAntes => $composableBuilder(
      column: $table.localizacaoFotosAntes,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get localizacaoFotosDepois => $composableBuilder(
      column: $table.localizacaoFotosDepois,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fotosAntesJson => $composableBuilder(
      column: $table.fotosAntesJson,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fotosDepoisJson => $composableBuilder(
      column: $table.fotosDepoisJson,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get checkPergunta1 => $composableBuilder(
      column: $table.checkPergunta1,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get obsPergunta1 => $composableBuilder(
      column: $table.obsPergunta1, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get checkPergunta2 => $composableBuilder(
      column: $table.checkPergunta2,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get obsPergunta2 => $composableBuilder(
      column: $table.obsPergunta2, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get checkPergunta3 => $composableBuilder(
      column: $table.checkPergunta3,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get obsPergunta3 => $composableBuilder(
      column: $table.obsPergunta3, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get checkPergunta4 => $composableBuilder(
      column: $table.checkPergunta4,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get obsPergunta4 => $composableBuilder(
      column: $table.obsPergunta4, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get checkPergunta5 => $composableBuilder(
      column: $table.checkPergunta5,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get obsPergunta5 => $composableBuilder(
      column: $table.obsPergunta5, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get checkPergunta6 => $composableBuilder(
      column: $table.checkPergunta6,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get obsPergunta6 => $composableBuilder(
      column: $table.obsPergunta6, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get checkPergunta7 => $composableBuilder(
      column: $table.checkPergunta7,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get obsPergunta7 => $composableBuilder(
      column: $table.obsPergunta7, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get comentariosVisita => $composableBuilder(
      column: $table.comentariosVisita,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get localState => $composableBuilder(
      column: $table.localState, builder: (column) => ColumnFilters(column));
}

class $$VisitasTableOrderingComposer
    extends Composer<_$AppDatabase, $VisitasTable> {
  $$VisitasTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get idPdvAssociado => $composableBuilder(
      column: $table.idPdvAssociado,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get idPromotorAssociado => $composableBuilder(
      column: $table.idPromotorAssociado,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get diaHoraAgendado => $composableBuilder(
      column: $table.diaHoraAgendado,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get diaHoraRealizado => $composableBuilder(
      column: $table.diaHoraRealizado,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get diaHoraAbertura => $composableBuilder(
      column: $table.diaHoraAbertura,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get statusVisita => $composableBuilder(
      column: $table.statusVisita,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get rotaAssociada => $composableBuilder(
      column: $table.rotaAssociada,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get idGabaritoAssociado => $composableBuilder(
      column: $table.idGabaritoAssociado,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get titulo => $composableBuilder(
      column: $table.titulo, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get previsaoTurnoRealizada => $composableBuilder(
      column: $table.previsaoTurnoRealizada,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get visitaAvulsa => $composableBuilder(
      column: $table.visitaAvulsa,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get serverId => $composableBuilder(
      column: $table.serverId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get localizacaoAbertura => $composableBuilder(
      column: $table.localizacaoAbertura,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get localizacaoEncerramento => $composableBuilder(
      column: $table.localizacaoEncerramento,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get diaHoraFotosAntes => $composableBuilder(
      column: $table.diaHoraFotosAntes,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get diaHoraFotosDepois => $composableBuilder(
      column: $table.diaHoraFotosDepois,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get localizacaoFotosAntes => $composableBuilder(
      column: $table.localizacaoFotosAntes,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get localizacaoFotosDepois => $composableBuilder(
      column: $table.localizacaoFotosDepois,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fotosAntesJson => $composableBuilder(
      column: $table.fotosAntesJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fotosDepoisJson => $composableBuilder(
      column: $table.fotosDepoisJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get checkPergunta1 => $composableBuilder(
      column: $table.checkPergunta1,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get obsPergunta1 => $composableBuilder(
      column: $table.obsPergunta1,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get checkPergunta2 => $composableBuilder(
      column: $table.checkPergunta2,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get obsPergunta2 => $composableBuilder(
      column: $table.obsPergunta2,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get checkPergunta3 => $composableBuilder(
      column: $table.checkPergunta3,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get obsPergunta3 => $composableBuilder(
      column: $table.obsPergunta3,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get checkPergunta4 => $composableBuilder(
      column: $table.checkPergunta4,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get obsPergunta4 => $composableBuilder(
      column: $table.obsPergunta4,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get checkPergunta5 => $composableBuilder(
      column: $table.checkPergunta5,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get obsPergunta5 => $composableBuilder(
      column: $table.obsPergunta5,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get checkPergunta6 => $composableBuilder(
      column: $table.checkPergunta6,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get obsPergunta6 => $composableBuilder(
      column: $table.obsPergunta6,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get checkPergunta7 => $composableBuilder(
      column: $table.checkPergunta7,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get obsPergunta7 => $composableBuilder(
      column: $table.obsPergunta7,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get comentariosVisita => $composableBuilder(
      column: $table.comentariosVisita,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get localState => $composableBuilder(
      column: $table.localState, builder: (column) => ColumnOrderings(column));
}

class $$VisitasTableAnnotationComposer
    extends Composer<_$AppDatabase, $VisitasTable> {
  $$VisitasTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get idPdvAssociado => $composableBuilder(
      column: $table.idPdvAssociado, builder: (column) => column);

  GeneratedColumn<int> get idPromotorAssociado => $composableBuilder(
      column: $table.idPromotorAssociado, builder: (column) => column);

  GeneratedColumn<String> get diaHoraAgendado => $composableBuilder(
      column: $table.diaHoraAgendado, builder: (column) => column);

  GeneratedColumn<String> get diaHoraRealizado => $composableBuilder(
      column: $table.diaHoraRealizado, builder: (column) => column);

  GeneratedColumn<String> get diaHoraAbertura => $composableBuilder(
      column: $table.diaHoraAbertura, builder: (column) => column);

  GeneratedColumn<int> get statusVisita => $composableBuilder(
      column: $table.statusVisita, builder: (column) => column);

  GeneratedColumn<int> get rotaAssociada => $composableBuilder(
      column: $table.rotaAssociada, builder: (column) => column);

  GeneratedColumn<int> get idGabaritoAssociado => $composableBuilder(
      column: $table.idGabaritoAssociado, builder: (column) => column);

  GeneratedColumn<String> get titulo =>
      $composableBuilder(column: $table.titulo, builder: (column) => column);

  GeneratedColumn<String> get previsaoTurnoRealizada => $composableBuilder(
      column: $table.previsaoTurnoRealizada, builder: (column) => column);

  GeneratedColumn<bool> get visitaAvulsa => $composableBuilder(
      column: $table.visitaAvulsa, builder: (column) => column);

  GeneratedColumn<int> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get localizacaoAbertura => $composableBuilder(
      column: $table.localizacaoAbertura, builder: (column) => column);

  GeneratedColumn<String> get localizacaoEncerramento => $composableBuilder(
      column: $table.localizacaoEncerramento, builder: (column) => column);

  GeneratedColumn<String> get diaHoraFotosAntes => $composableBuilder(
      column: $table.diaHoraFotosAntes, builder: (column) => column);

  GeneratedColumn<String> get diaHoraFotosDepois => $composableBuilder(
      column: $table.diaHoraFotosDepois, builder: (column) => column);

  GeneratedColumn<String> get localizacaoFotosAntes => $composableBuilder(
      column: $table.localizacaoFotosAntes, builder: (column) => column);

  GeneratedColumn<String> get localizacaoFotosDepois => $composableBuilder(
      column: $table.localizacaoFotosDepois, builder: (column) => column);

  GeneratedColumn<String> get fotosAntesJson => $composableBuilder(
      column: $table.fotosAntesJson, builder: (column) => column);

  GeneratedColumn<String> get fotosDepoisJson => $composableBuilder(
      column: $table.fotosDepoisJson, builder: (column) => column);

  GeneratedColumn<bool> get checkPergunta1 => $composableBuilder(
      column: $table.checkPergunta1, builder: (column) => column);

  GeneratedColumn<String> get obsPergunta1 => $composableBuilder(
      column: $table.obsPergunta1, builder: (column) => column);

  GeneratedColumn<bool> get checkPergunta2 => $composableBuilder(
      column: $table.checkPergunta2, builder: (column) => column);

  GeneratedColumn<String> get obsPergunta2 => $composableBuilder(
      column: $table.obsPergunta2, builder: (column) => column);

  GeneratedColumn<bool> get checkPergunta3 => $composableBuilder(
      column: $table.checkPergunta3, builder: (column) => column);

  GeneratedColumn<String> get obsPergunta3 => $composableBuilder(
      column: $table.obsPergunta3, builder: (column) => column);

  GeneratedColumn<bool> get checkPergunta4 => $composableBuilder(
      column: $table.checkPergunta4, builder: (column) => column);

  GeneratedColumn<String> get obsPergunta4 => $composableBuilder(
      column: $table.obsPergunta4, builder: (column) => column);

  GeneratedColumn<bool> get checkPergunta5 => $composableBuilder(
      column: $table.checkPergunta5, builder: (column) => column);

  GeneratedColumn<String> get obsPergunta5 => $composableBuilder(
      column: $table.obsPergunta5, builder: (column) => column);

  GeneratedColumn<bool> get checkPergunta6 => $composableBuilder(
      column: $table.checkPergunta6, builder: (column) => column);

  GeneratedColumn<String> get obsPergunta6 => $composableBuilder(
      column: $table.obsPergunta6, builder: (column) => column);

  GeneratedColumn<bool> get checkPergunta7 => $composableBuilder(
      column: $table.checkPergunta7, builder: (column) => column);

  GeneratedColumn<String> get obsPergunta7 => $composableBuilder(
      column: $table.obsPergunta7, builder: (column) => column);

  GeneratedColumn<String> get comentariosVisita => $composableBuilder(
      column: $table.comentariosVisita, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => column);

  GeneratedColumn<String> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  GeneratedColumn<String> get localState => $composableBuilder(
      column: $table.localState, builder: (column) => column);
}

class $$VisitasTableTableManager extends RootTableManager<
    _$AppDatabase,
    $VisitasTable,
    Visita,
    $$VisitasTableFilterComposer,
    $$VisitasTableOrderingComposer,
    $$VisitasTableAnnotationComposer,
    $$VisitasTableCreateCompanionBuilder,
    $$VisitasTableUpdateCompanionBuilder,
    (Visita, BaseReferences<_$AppDatabase, $VisitasTable, Visita>),
    Visita,
    PrefetchHooks Function()> {
  $$VisitasTableTableManager(_$AppDatabase db, $VisitasTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VisitasTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VisitasTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VisitasTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int?> idPdvAssociado = const Value.absent(),
            Value<int?> idPromotorAssociado = const Value.absent(),
            Value<String?> diaHoraAgendado = const Value.absent(),
            Value<String?> diaHoraRealizado = const Value.absent(),
            Value<String?> diaHoraAbertura = const Value.absent(),
            Value<int?> statusVisita = const Value.absent(),
            Value<int?> rotaAssociada = const Value.absent(),
            Value<int?> idGabaritoAssociado = const Value.absent(),
            Value<String?> titulo = const Value.absent(),
            Value<String?> previsaoTurnoRealizada = const Value.absent(),
            Value<bool?> visitaAvulsa = const Value.absent(),
            Value<int?> serverId = const Value.absent(),
            Value<String?> localizacaoAbertura = const Value.absent(),
            Value<String?> localizacaoEncerramento = const Value.absent(),
            Value<String?> diaHoraFotosAntes = const Value.absent(),
            Value<String?> diaHoraFotosDepois = const Value.absent(),
            Value<String?> localizacaoFotosAntes = const Value.absent(),
            Value<String?> localizacaoFotosDepois = const Value.absent(),
            Value<String?> fotosAntesJson = const Value.absent(),
            Value<String?> fotosDepoisJson = const Value.absent(),
            Value<bool?> checkPergunta1 = const Value.absent(),
            Value<String?> obsPergunta1 = const Value.absent(),
            Value<bool?> checkPergunta2 = const Value.absent(),
            Value<String?> obsPergunta2 = const Value.absent(),
            Value<bool?> checkPergunta3 = const Value.absent(),
            Value<String?> obsPergunta3 = const Value.absent(),
            Value<bool?> checkPergunta4 = const Value.absent(),
            Value<String?> obsPergunta4 = const Value.absent(),
            Value<bool?> checkPergunta5 = const Value.absent(),
            Value<String?> obsPergunta5 = const Value.absent(),
            Value<bool?> checkPergunta6 = const Value.absent(),
            Value<String?> obsPergunta6 = const Value.absent(),
            Value<bool?> checkPergunta7 = const Value.absent(),
            Value<String?> obsPergunta7 = const Value.absent(),
            Value<String?> comentariosVisita = const Value.absent(),
            Value<String> syncStatus = const Value.absent(),
            Value<String?> syncedAt = const Value.absent(),
            Value<String> localState = const Value.absent(),
          }) =>
              VisitasCompanion(
            id: id,
            idPdvAssociado: idPdvAssociado,
            idPromotorAssociado: idPromotorAssociado,
            diaHoraAgendado: diaHoraAgendado,
            diaHoraRealizado: diaHoraRealizado,
            diaHoraAbertura: diaHoraAbertura,
            statusVisita: statusVisita,
            rotaAssociada: rotaAssociada,
            idGabaritoAssociado: idGabaritoAssociado,
            titulo: titulo,
            previsaoTurnoRealizada: previsaoTurnoRealizada,
            visitaAvulsa: visitaAvulsa,
            serverId: serverId,
            localizacaoAbertura: localizacaoAbertura,
            localizacaoEncerramento: localizacaoEncerramento,
            diaHoraFotosAntes: diaHoraFotosAntes,
            diaHoraFotosDepois: diaHoraFotosDepois,
            localizacaoFotosAntes: localizacaoFotosAntes,
            localizacaoFotosDepois: localizacaoFotosDepois,
            fotosAntesJson: fotosAntesJson,
            fotosDepoisJson: fotosDepoisJson,
            checkPergunta1: checkPergunta1,
            obsPergunta1: obsPergunta1,
            checkPergunta2: checkPergunta2,
            obsPergunta2: obsPergunta2,
            checkPergunta3: checkPergunta3,
            obsPergunta3: obsPergunta3,
            checkPergunta4: checkPergunta4,
            obsPergunta4: obsPergunta4,
            checkPergunta5: checkPergunta5,
            obsPergunta5: obsPergunta5,
            checkPergunta6: checkPergunta6,
            obsPergunta6: obsPergunta6,
            checkPergunta7: checkPergunta7,
            obsPergunta7: obsPergunta7,
            comentariosVisita: comentariosVisita,
            syncStatus: syncStatus,
            syncedAt: syncedAt,
            localState: localState,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int?> idPdvAssociado = const Value.absent(),
            Value<int?> idPromotorAssociado = const Value.absent(),
            Value<String?> diaHoraAgendado = const Value.absent(),
            Value<String?> diaHoraRealizado = const Value.absent(),
            Value<String?> diaHoraAbertura = const Value.absent(),
            Value<int?> statusVisita = const Value.absent(),
            Value<int?> rotaAssociada = const Value.absent(),
            Value<int?> idGabaritoAssociado = const Value.absent(),
            Value<String?> titulo = const Value.absent(),
            Value<String?> previsaoTurnoRealizada = const Value.absent(),
            Value<bool?> visitaAvulsa = const Value.absent(),
            Value<int?> serverId = const Value.absent(),
            Value<String?> localizacaoAbertura = const Value.absent(),
            Value<String?> localizacaoEncerramento = const Value.absent(),
            Value<String?> diaHoraFotosAntes = const Value.absent(),
            Value<String?> diaHoraFotosDepois = const Value.absent(),
            Value<String?> localizacaoFotosAntes = const Value.absent(),
            Value<String?> localizacaoFotosDepois = const Value.absent(),
            Value<String?> fotosAntesJson = const Value.absent(),
            Value<String?> fotosDepoisJson = const Value.absent(),
            Value<bool?> checkPergunta1 = const Value.absent(),
            Value<String?> obsPergunta1 = const Value.absent(),
            Value<bool?> checkPergunta2 = const Value.absent(),
            Value<String?> obsPergunta2 = const Value.absent(),
            Value<bool?> checkPergunta3 = const Value.absent(),
            Value<String?> obsPergunta3 = const Value.absent(),
            Value<bool?> checkPergunta4 = const Value.absent(),
            Value<String?> obsPergunta4 = const Value.absent(),
            Value<bool?> checkPergunta5 = const Value.absent(),
            Value<String?> obsPergunta5 = const Value.absent(),
            Value<bool?> checkPergunta6 = const Value.absent(),
            Value<String?> obsPergunta6 = const Value.absent(),
            Value<bool?> checkPergunta7 = const Value.absent(),
            Value<String?> obsPergunta7 = const Value.absent(),
            Value<String?> comentariosVisita = const Value.absent(),
            Value<String> syncStatus = const Value.absent(),
            Value<String?> syncedAt = const Value.absent(),
            Value<String> localState = const Value.absent(),
          }) =>
              VisitasCompanion.insert(
            id: id,
            idPdvAssociado: idPdvAssociado,
            idPromotorAssociado: idPromotorAssociado,
            diaHoraAgendado: diaHoraAgendado,
            diaHoraRealizado: diaHoraRealizado,
            diaHoraAbertura: diaHoraAbertura,
            statusVisita: statusVisita,
            rotaAssociada: rotaAssociada,
            idGabaritoAssociado: idGabaritoAssociado,
            titulo: titulo,
            previsaoTurnoRealizada: previsaoTurnoRealizada,
            visitaAvulsa: visitaAvulsa,
            serverId: serverId,
            localizacaoAbertura: localizacaoAbertura,
            localizacaoEncerramento: localizacaoEncerramento,
            diaHoraFotosAntes: diaHoraFotosAntes,
            diaHoraFotosDepois: diaHoraFotosDepois,
            localizacaoFotosAntes: localizacaoFotosAntes,
            localizacaoFotosDepois: localizacaoFotosDepois,
            fotosAntesJson: fotosAntesJson,
            fotosDepoisJson: fotosDepoisJson,
            checkPergunta1: checkPergunta1,
            obsPergunta1: obsPergunta1,
            checkPergunta2: checkPergunta2,
            obsPergunta2: obsPergunta2,
            checkPergunta3: checkPergunta3,
            obsPergunta3: obsPergunta3,
            checkPergunta4: checkPergunta4,
            obsPergunta4: obsPergunta4,
            checkPergunta5: checkPergunta5,
            obsPergunta5: obsPergunta5,
            checkPergunta6: checkPergunta6,
            obsPergunta6: obsPergunta6,
            checkPergunta7: checkPergunta7,
            obsPergunta7: obsPergunta7,
            comentariosVisita: comentariosVisita,
            syncStatus: syncStatus,
            syncedAt: syncedAt,
            localState: localState,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$VisitasTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $VisitasTable,
    Visita,
    $$VisitasTableFilterComposer,
    $$VisitasTableOrderingComposer,
    $$VisitasTableAnnotationComposer,
    $$VisitasTableCreateCompanionBuilder,
    $$VisitasTableUpdateCompanionBuilder,
    (Visita, BaseReferences<_$AppDatabase, $VisitasTable, Visita>),
    Visita,
    PrefetchHooks Function()>;
typedef $$OutboxItemsTableCreateCompanionBuilder = OutboxItemsCompanion
    Function({
  required String id,
  required String entityType,
  required String operation,
  required int entityId,
  required String payloadJson,
  Value<int> attempts,
  required String nextRetryAt,
  Value<String?> lastError,
  Value<String> status,
  required String createdAt,
  Value<int> rowid,
});
typedef $$OutboxItemsTableUpdateCompanionBuilder = OutboxItemsCompanion
    Function({
  Value<String> id,
  Value<String> entityType,
  Value<String> operation,
  Value<int> entityId,
  Value<String> payloadJson,
  Value<int> attempts,
  Value<String> nextRetryAt,
  Value<String?> lastError,
  Value<String> status,
  Value<String> createdAt,
  Value<int> rowid,
});

class $$OutboxItemsTableFilterComposer
    extends Composer<_$AppDatabase, $OutboxItemsTable> {
  $$OutboxItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get operation => $composableBuilder(
      column: $table.operation, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get entityId => $composableBuilder(
      column: $table.entityId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get attempts => $composableBuilder(
      column: $table.attempts, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get nextRetryAt => $composableBuilder(
      column: $table.nextRetryAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$OutboxItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $OutboxItemsTable> {
  $$OutboxItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get operation => $composableBuilder(
      column: $table.operation, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get entityId => $composableBuilder(
      column: $table.entityId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get attempts => $composableBuilder(
      column: $table.attempts, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get nextRetryAt => $composableBuilder(
      column: $table.nextRetryAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$OutboxItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutboxItemsTable> {
  $$OutboxItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => column);

  GeneratedColumn<String> get operation =>
      $composableBuilder(column: $table.operation, builder: (column) => column);

  GeneratedColumn<int> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get nextRetryAt => $composableBuilder(
      column: $table.nextRetryAt, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$OutboxItemsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $OutboxItemsTable,
    OutboxItem,
    $$OutboxItemsTableFilterComposer,
    $$OutboxItemsTableOrderingComposer,
    $$OutboxItemsTableAnnotationComposer,
    $$OutboxItemsTableCreateCompanionBuilder,
    $$OutboxItemsTableUpdateCompanionBuilder,
    (OutboxItem, BaseReferences<_$AppDatabase, $OutboxItemsTable, OutboxItem>),
    OutboxItem,
    PrefetchHooks Function()> {
  $$OutboxItemsTableTableManager(_$AppDatabase db, $OutboxItemsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> entityType = const Value.absent(),
            Value<String> operation = const Value.absent(),
            Value<int> entityId = const Value.absent(),
            Value<String> payloadJson = const Value.absent(),
            Value<int> attempts = const Value.absent(),
            Value<String> nextRetryAt = const Value.absent(),
            Value<String?> lastError = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              OutboxItemsCompanion(
            id: id,
            entityType: entityType,
            operation: operation,
            entityId: entityId,
            payloadJson: payloadJson,
            attempts: attempts,
            nextRetryAt: nextRetryAt,
            lastError: lastError,
            status: status,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String entityType,
            required String operation,
            required int entityId,
            required String payloadJson,
            Value<int> attempts = const Value.absent(),
            required String nextRetryAt,
            Value<String?> lastError = const Value.absent(),
            Value<String> status = const Value.absent(),
            required String createdAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              OutboxItemsCompanion.insert(
            id: id,
            entityType: entityType,
            operation: operation,
            entityId: entityId,
            payloadJson: payloadJson,
            attempts: attempts,
            nextRetryAt: nextRetryAt,
            lastError: lastError,
            status: status,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$OutboxItemsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $OutboxItemsTable,
    OutboxItem,
    $$OutboxItemsTableFilterComposer,
    $$OutboxItemsTableOrderingComposer,
    $$OutboxItemsTableAnnotationComposer,
    $$OutboxItemsTableCreateCompanionBuilder,
    $$OutboxItemsTableUpdateCompanionBuilder,
    (OutboxItem, BaseReferences<_$AppDatabase, $OutboxItemsTable, OutboxItem>),
    OutboxItem,
    PrefetchHooks Function()>;
typedef $$PendingPhotosTableCreateCompanionBuilder = PendingPhotosCompanion
    Function({
  required String id,
  required int visitaId,
  required String slot,
  required int numero,
  required String localPath,
  Value<String> status,
  Value<String?> storageUrl,
  Value<int> attempts,
  required String nextRetryAt,
  required String createdAt,
  Value<int> rowid,
});
typedef $$PendingPhotosTableUpdateCompanionBuilder = PendingPhotosCompanion
    Function({
  Value<String> id,
  Value<int> visitaId,
  Value<String> slot,
  Value<int> numero,
  Value<String> localPath,
  Value<String> status,
  Value<String?> storageUrl,
  Value<int> attempts,
  Value<String> nextRetryAt,
  Value<String> createdAt,
  Value<int> rowid,
});

class $$PendingPhotosTableFilterComposer
    extends Composer<_$AppDatabase, $PendingPhotosTable> {
  $$PendingPhotosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get visitaId => $composableBuilder(
      column: $table.visitaId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get slot => $composableBuilder(
      column: $table.slot, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get numero => $composableBuilder(
      column: $table.numero, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get localPath => $composableBuilder(
      column: $table.localPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get storageUrl => $composableBuilder(
      column: $table.storageUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get attempts => $composableBuilder(
      column: $table.attempts, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get nextRetryAt => $composableBuilder(
      column: $table.nextRetryAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$PendingPhotosTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingPhotosTable> {
  $$PendingPhotosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get visitaId => $composableBuilder(
      column: $table.visitaId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get slot => $composableBuilder(
      column: $table.slot, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get numero => $composableBuilder(
      column: $table.numero, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get localPath => $composableBuilder(
      column: $table.localPath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get storageUrl => $composableBuilder(
      column: $table.storageUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get attempts => $composableBuilder(
      column: $table.attempts, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get nextRetryAt => $composableBuilder(
      column: $table.nextRetryAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$PendingPhotosTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingPhotosTable> {
  $$PendingPhotosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get visitaId =>
      $composableBuilder(column: $table.visitaId, builder: (column) => column);

  GeneratedColumn<String> get slot =>
      $composableBuilder(column: $table.slot, builder: (column) => column);

  GeneratedColumn<int> get numero =>
      $composableBuilder(column: $table.numero, builder: (column) => column);

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get storageUrl => $composableBuilder(
      column: $table.storageUrl, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get nextRetryAt => $composableBuilder(
      column: $table.nextRetryAt, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$PendingPhotosTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PendingPhotosTable,
    PendingPhoto,
    $$PendingPhotosTableFilterComposer,
    $$PendingPhotosTableOrderingComposer,
    $$PendingPhotosTableAnnotationComposer,
    $$PendingPhotosTableCreateCompanionBuilder,
    $$PendingPhotosTableUpdateCompanionBuilder,
    (
      PendingPhoto,
      BaseReferences<_$AppDatabase, $PendingPhotosTable, PendingPhoto>
    ),
    PendingPhoto,
    PrefetchHooks Function()> {
  $$PendingPhotosTableTableManager(_$AppDatabase db, $PendingPhotosTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingPhotosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingPhotosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingPhotosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<int> visitaId = const Value.absent(),
            Value<String> slot = const Value.absent(),
            Value<int> numero = const Value.absent(),
            Value<String> localPath = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String?> storageUrl = const Value.absent(),
            Value<int> attempts = const Value.absent(),
            Value<String> nextRetryAt = const Value.absent(),
            Value<String> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PendingPhotosCompanion(
            id: id,
            visitaId: visitaId,
            slot: slot,
            numero: numero,
            localPath: localPath,
            status: status,
            storageUrl: storageUrl,
            attempts: attempts,
            nextRetryAt: nextRetryAt,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required int visitaId,
            required String slot,
            required int numero,
            required String localPath,
            Value<String> status = const Value.absent(),
            Value<String?> storageUrl = const Value.absent(),
            Value<int> attempts = const Value.absent(),
            required String nextRetryAt,
            required String createdAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              PendingPhotosCompanion.insert(
            id: id,
            visitaId: visitaId,
            slot: slot,
            numero: numero,
            localPath: localPath,
            status: status,
            storageUrl: storageUrl,
            attempts: attempts,
            nextRetryAt: nextRetryAt,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PendingPhotosTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PendingPhotosTable,
    PendingPhoto,
    $$PendingPhotosTableFilterComposer,
    $$PendingPhotosTableOrderingComposer,
    $$PendingPhotosTableAnnotationComposer,
    $$PendingPhotosTableCreateCompanionBuilder,
    $$PendingPhotosTableUpdateCompanionBuilder,
    (
      PendingPhoto,
      BaseReferences<_$AppDatabase, $PendingPhotosTable, PendingPhoto>
    ),
    PendingPhoto,
    PrefetchHooks Function()>;
typedef $$SyncStateTableCreateCompanionBuilder = SyncStateCompanion Function({
  required String entityType,
  Value<String?> lastPullAt,
  Value<String?> lastPushAt,
  Value<int> rowid,
});
typedef $$SyncStateTableUpdateCompanionBuilder = SyncStateCompanion Function({
  Value<String> entityType,
  Value<String?> lastPullAt,
  Value<String?> lastPushAt,
  Value<int> rowid,
});

class $$SyncStateTableFilterComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastPullAt => $composableBuilder(
      column: $table.lastPullAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastPushAt => $composableBuilder(
      column: $table.lastPushAt, builder: (column) => ColumnFilters(column));
}

class $$SyncStateTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastPullAt => $composableBuilder(
      column: $table.lastPullAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastPushAt => $composableBuilder(
      column: $table.lastPushAt, builder: (column) => ColumnOrderings(column));
}

class $$SyncStateTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => column);

  GeneratedColumn<String> get lastPullAt => $composableBuilder(
      column: $table.lastPullAt, builder: (column) => column);

  GeneratedColumn<String> get lastPushAt => $composableBuilder(
      column: $table.lastPushAt, builder: (column) => column);
}

class $$SyncStateTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SyncStateTable,
    SyncStateData,
    $$SyncStateTableFilterComposer,
    $$SyncStateTableOrderingComposer,
    $$SyncStateTableAnnotationComposer,
    $$SyncStateTableCreateCompanionBuilder,
    $$SyncStateTableUpdateCompanionBuilder,
    (
      SyncStateData,
      BaseReferences<_$AppDatabase, $SyncStateTable, SyncStateData>
    ),
    SyncStateData,
    PrefetchHooks Function()> {
  $$SyncStateTableTableManager(_$AppDatabase db, $SyncStateTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncStateTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncStateTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncStateTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> entityType = const Value.absent(),
            Value<String?> lastPullAt = const Value.absent(),
            Value<String?> lastPushAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncStateCompanion(
            entityType: entityType,
            lastPullAt: lastPullAt,
            lastPushAt: lastPushAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String entityType,
            Value<String?> lastPullAt = const Value.absent(),
            Value<String?> lastPushAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncStateCompanion.insert(
            entityType: entityType,
            lastPullAt: lastPullAt,
            lastPushAt: lastPushAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SyncStateTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SyncStateTable,
    SyncStateData,
    $$SyncStateTableFilterComposer,
    $$SyncStateTableOrderingComposer,
    $$SyncStateTableAnnotationComposer,
    $$SyncStateTableCreateCompanionBuilder,
    $$SyncStateTableUpdateCompanionBuilder,
    (
      SyncStateData,
      BaseReferences<_$AppDatabase, $SyncStateTable, SyncStateData>
    ),
    SyncStateData,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db, _db.users);
  $$PdvsTableTableManager get pdvs => $$PdvsTableTableManager(_db, _db.pdvs);
  $$GabaritosTableTableManager get gabaritos =>
      $$GabaritosTableTableManager(_db, _db.gabaritos);
  $$VisitasTableTableManager get visitas =>
      $$VisitasTableTableManager(_db, _db.visitas);
  $$OutboxItemsTableTableManager get outboxItems =>
      $$OutboxItemsTableTableManager(_db, _db.outboxItems);
  $$PendingPhotosTableTableManager get pendingPhotos =>
      $$PendingPhotosTableTableManager(_db, _db.pendingPhotos);
  $$SyncStateTableTableManager get syncState =>
      $$SyncStateTableTableManager(_db, _db.syncState);
}
