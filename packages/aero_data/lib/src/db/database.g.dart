// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $RepositoriesTable extends Repositories
    with TableInfo<$RepositoriesTable, PluginRepoRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RepositoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ecosystemMeta = const VerificationMeta(
    'ecosystem',
  );
  @override
  late final GeneratedColumn<String> ecosystem = GeneratedColumn<String>(
    'ecosystem',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSyncMeta = const VerificationMeta(
    'lastSync',
  );
  @override
  late final GeneratedColumn<DateTime> lastSync = GeneratedColumn<DateTime>(
    'last_sync',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ecosystem,
    url,
    name,
    lastSync,
    enabled,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'repositories';
  @override
  VerificationContext validateIntegrity(
    Insertable<PluginRepoRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('ecosystem')) {
      context.handle(
        _ecosystemMeta,
        ecosystem.isAcceptableOrUnknown(data['ecosystem']!, _ecosystemMeta),
      );
    } else if (isInserting) {
      context.missing(_ecosystemMeta);
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('last_sync')) {
      context.handle(
        _lastSyncMeta,
        lastSync.isAcceptableOrUnknown(data['last_sync']!, _lastSyncMeta),
      );
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id, ecosystem};
  @override
  PluginRepoRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PluginRepoRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      ecosystem: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ecosystem'],
      )!,
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      lastSync: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_sync'],
      ),
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
    );
  }

  @override
  $RepositoriesTable createAlias(String alias) {
    return $RepositoriesTable(attachedDatabase, alias);
  }
}

class PluginRepoRow extends DataClass implements Insertable<PluginRepoRow> {
  final String id;
  final String ecosystem;
  final String url;
  final String name;
  final DateTime? lastSync;
  final bool enabled;
  const PluginRepoRow({
    required this.id,
    required this.ecosystem,
    required this.url,
    required this.name,
    this.lastSync,
    required this.enabled,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['ecosystem'] = Variable<String>(ecosystem);
    map['url'] = Variable<String>(url);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || lastSync != null) {
      map['last_sync'] = Variable<DateTime>(lastSync);
    }
    map['enabled'] = Variable<bool>(enabled);
    return map;
  }

  RepositoriesCompanion toCompanion(bool nullToAbsent) {
    return RepositoriesCompanion(
      id: Value(id),
      ecosystem: Value(ecosystem),
      url: Value(url),
      name: Value(name),
      lastSync: lastSync == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSync),
      enabled: Value(enabled),
    );
  }

  factory PluginRepoRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PluginRepoRow(
      id: serializer.fromJson<String>(json['id']),
      ecosystem: serializer.fromJson<String>(json['ecosystem']),
      url: serializer.fromJson<String>(json['url']),
      name: serializer.fromJson<String>(json['name']),
      lastSync: serializer.fromJson<DateTime?>(json['lastSync']),
      enabled: serializer.fromJson<bool>(json['enabled']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'ecosystem': serializer.toJson<String>(ecosystem),
      'url': serializer.toJson<String>(url),
      'name': serializer.toJson<String>(name),
      'lastSync': serializer.toJson<DateTime?>(lastSync),
      'enabled': serializer.toJson<bool>(enabled),
    };
  }

  PluginRepoRow copyWith({
    String? id,
    String? ecosystem,
    String? url,
    String? name,
    Value<DateTime?> lastSync = const Value.absent(),
    bool? enabled,
  }) => PluginRepoRow(
    id: id ?? this.id,
    ecosystem: ecosystem ?? this.ecosystem,
    url: url ?? this.url,
    name: name ?? this.name,
    lastSync: lastSync.present ? lastSync.value : this.lastSync,
    enabled: enabled ?? this.enabled,
  );
  PluginRepoRow copyWithCompanion(RepositoriesCompanion data) {
    return PluginRepoRow(
      id: data.id.present ? data.id.value : this.id,
      ecosystem: data.ecosystem.present ? data.ecosystem.value : this.ecosystem,
      url: data.url.present ? data.url.value : this.url,
      name: data.name.present ? data.name.value : this.name,
      lastSync: data.lastSync.present ? data.lastSync.value : this.lastSync,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PluginRepoRow(')
          ..write('id: $id, ')
          ..write('ecosystem: $ecosystem, ')
          ..write('url: $url, ')
          ..write('name: $name, ')
          ..write('lastSync: $lastSync, ')
          ..write('enabled: $enabled')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, ecosystem, url, name, lastSync, enabled);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PluginRepoRow &&
          other.id == this.id &&
          other.ecosystem == this.ecosystem &&
          other.url == this.url &&
          other.name == this.name &&
          other.lastSync == this.lastSync &&
          other.enabled == this.enabled);
}

class RepositoriesCompanion extends UpdateCompanion<PluginRepoRow> {
  final Value<String> id;
  final Value<String> ecosystem;
  final Value<String> url;
  final Value<String> name;
  final Value<DateTime?> lastSync;
  final Value<bool> enabled;
  final Value<int> rowid;
  const RepositoriesCompanion({
    this.id = const Value.absent(),
    this.ecosystem = const Value.absent(),
    this.url = const Value.absent(),
    this.name = const Value.absent(),
    this.lastSync = const Value.absent(),
    this.enabled = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RepositoriesCompanion.insert({
    required String id,
    required String ecosystem,
    required String url,
    required String name,
    this.lastSync = const Value.absent(),
    this.enabled = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       ecosystem = Value(ecosystem),
       url = Value(url),
       name = Value(name);
  static Insertable<PluginRepoRow> custom({
    Expression<String>? id,
    Expression<String>? ecosystem,
    Expression<String>? url,
    Expression<String>? name,
    Expression<DateTime>? lastSync,
    Expression<bool>? enabled,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ecosystem != null) 'ecosystem': ecosystem,
      if (url != null) 'url': url,
      if (name != null) 'name': name,
      if (lastSync != null) 'last_sync': lastSync,
      if (enabled != null) 'enabled': enabled,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RepositoriesCompanion copyWith({
    Value<String>? id,
    Value<String>? ecosystem,
    Value<String>? url,
    Value<String>? name,
    Value<DateTime?>? lastSync,
    Value<bool>? enabled,
    Value<int>? rowid,
  }) {
    return RepositoriesCompanion(
      id: id ?? this.id,
      ecosystem: ecosystem ?? this.ecosystem,
      url: url ?? this.url,
      name: name ?? this.name,
      lastSync: lastSync ?? this.lastSync,
      enabled: enabled ?? this.enabled,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (ecosystem.present) {
      map['ecosystem'] = Variable<String>(ecosystem.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (lastSync.present) {
      map['last_sync'] = Variable<DateTime>(lastSync.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RepositoriesCompanion(')
          ..write('id: $id, ')
          ..write('ecosystem: $ecosystem, ')
          ..write('url: $url, ')
          ..write('name: $name, ')
          ..write('lastSync: $lastSync, ')
          ..write('enabled: $enabled, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $InstalledSourcesTable extends InstalledSources
    with TableInfo<$InstalledSourcesTable, InstalledSourceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InstalledSourcesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ecosystemMeta = const VerificationMeta(
    'ecosystem',
  );
  @override
  late final GeneratedColumn<String> ecosystem = GeneratedColumn<String>(
    'ecosystem',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _repoIdMeta = const VerificationMeta('repoId');
  @override
  late final GeneratedColumn<String> repoId = GeneratedColumn<String>(
    'repo_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<String> version = GeneratedColumn<String>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('0.0.0'),
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _logoMeta = const VerificationMeta('logo');
  @override
  late final GeneratedColumn<String> logo = GeneratedColumn<String>(
    'logo',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(100),
  );
  static const VerificationMeta _configJsonMeta = const VerificationMeta(
    'configJson',
  );
  @override
  late final GeneratedColumn<String> configJson = GeneratedColumn<String>(
    'config_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _sha256Meta = const VerificationMeta('sha256');
  @override
  late final GeneratedColumn<String> sha256 = GeneratedColumn<String>(
    'sha256',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _adultMeta = const VerificationMeta('adult');
  @override
  late final GeneratedColumn<bool> adult = GeneratedColumn<bool>(
    'adult',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("adult" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _installedAtMeta = const VerificationMeta(
    'installedAt',
  );
  @override
  late final GeneratedColumn<DateTime> installedAt = GeneratedColumn<DateTime>(
    'installed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ecosystem,
    repoId,
    name,
    url,
    version,
    description,
    logo,
    enabled,
    priority,
    configJson,
    sha256,
    adult,
    installedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'installed_sources';
  @override
  VerificationContext validateIntegrity(
    Insertable<InstalledSourceRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('ecosystem')) {
      context.handle(
        _ecosystemMeta,
        ecosystem.isAcceptableOrUnknown(data['ecosystem']!, _ecosystemMeta),
      );
    } else if (isInserting) {
      context.missing(_ecosystemMeta);
    }
    if (data.containsKey('repo_id')) {
      context.handle(
        _repoIdMeta,
        repoId.isAcceptableOrUnknown(data['repo_id']!, _repoIdMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('logo')) {
      context.handle(
        _logoMeta,
        logo.isAcceptableOrUnknown(data['logo']!, _logoMeta),
      );
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    }
    if (data.containsKey('config_json')) {
      context.handle(
        _configJsonMeta,
        configJson.isAcceptableOrUnknown(data['config_json']!, _configJsonMeta),
      );
    }
    if (data.containsKey('sha256')) {
      context.handle(
        _sha256Meta,
        sha256.isAcceptableOrUnknown(data['sha256']!, _sha256Meta),
      );
    }
    if (data.containsKey('adult')) {
      context.handle(
        _adultMeta,
        adult.isAcceptableOrUnknown(data['adult']!, _adultMeta),
      );
    }
    if (data.containsKey('installed_at')) {
      context.handle(
        _installedAtMeta,
        installedAt.isAcceptableOrUnknown(
          data['installed_at']!,
          _installedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id, ecosystem};
  @override
  InstalledSourceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InstalledSourceRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      ecosystem: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ecosystem'],
      )!,
      repoId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}repo_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}version'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      logo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}logo'],
      ),
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      )!,
      configJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}config_json'],
      )!,
      sha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sha256'],
      ),
      adult: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}adult'],
      )!,
      installedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}installed_at'],
      ),
    );
  }

  @override
  $InstalledSourcesTable createAlias(String alias) {
    return $InstalledSourcesTable(attachedDatabase, alias);
  }
}

class InstalledSourceRow extends DataClass
    implements Insertable<InstalledSourceRow> {
  final String id;
  final String ecosystem;
  final String? repoId;
  final String name;
  final String url;
  final String version;
  final String? description;
  final String? logo;
  final bool enabled;
  final int priority;

  /// JSON blob: capabilities, types, idPrefixes, catalogs, per-plugin config.
  final String configJson;
  final String? sha256;
  final bool adult;
  final DateTime? installedAt;
  const InstalledSourceRow({
    required this.id,
    required this.ecosystem,
    this.repoId,
    required this.name,
    required this.url,
    required this.version,
    this.description,
    this.logo,
    required this.enabled,
    required this.priority,
    required this.configJson,
    this.sha256,
    required this.adult,
    this.installedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['ecosystem'] = Variable<String>(ecosystem);
    if (!nullToAbsent || repoId != null) {
      map['repo_id'] = Variable<String>(repoId);
    }
    map['name'] = Variable<String>(name);
    map['url'] = Variable<String>(url);
    map['version'] = Variable<String>(version);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || logo != null) {
      map['logo'] = Variable<String>(logo);
    }
    map['enabled'] = Variable<bool>(enabled);
    map['priority'] = Variable<int>(priority);
    map['config_json'] = Variable<String>(configJson);
    if (!nullToAbsent || sha256 != null) {
      map['sha256'] = Variable<String>(sha256);
    }
    map['adult'] = Variable<bool>(adult);
    if (!nullToAbsent || installedAt != null) {
      map['installed_at'] = Variable<DateTime>(installedAt);
    }
    return map;
  }

  InstalledSourcesCompanion toCompanion(bool nullToAbsent) {
    return InstalledSourcesCompanion(
      id: Value(id),
      ecosystem: Value(ecosystem),
      repoId: repoId == null && nullToAbsent
          ? const Value.absent()
          : Value(repoId),
      name: Value(name),
      url: Value(url),
      version: Value(version),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      logo: logo == null && nullToAbsent ? const Value.absent() : Value(logo),
      enabled: Value(enabled),
      priority: Value(priority),
      configJson: Value(configJson),
      sha256: sha256 == null && nullToAbsent
          ? const Value.absent()
          : Value(sha256),
      adult: Value(adult),
      installedAt: installedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(installedAt),
    );
  }

  factory InstalledSourceRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InstalledSourceRow(
      id: serializer.fromJson<String>(json['id']),
      ecosystem: serializer.fromJson<String>(json['ecosystem']),
      repoId: serializer.fromJson<String?>(json['repoId']),
      name: serializer.fromJson<String>(json['name']),
      url: serializer.fromJson<String>(json['url']),
      version: serializer.fromJson<String>(json['version']),
      description: serializer.fromJson<String?>(json['description']),
      logo: serializer.fromJson<String?>(json['logo']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      priority: serializer.fromJson<int>(json['priority']),
      configJson: serializer.fromJson<String>(json['configJson']),
      sha256: serializer.fromJson<String?>(json['sha256']),
      adult: serializer.fromJson<bool>(json['adult']),
      installedAt: serializer.fromJson<DateTime?>(json['installedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'ecosystem': serializer.toJson<String>(ecosystem),
      'repoId': serializer.toJson<String?>(repoId),
      'name': serializer.toJson<String>(name),
      'url': serializer.toJson<String>(url),
      'version': serializer.toJson<String>(version),
      'description': serializer.toJson<String?>(description),
      'logo': serializer.toJson<String?>(logo),
      'enabled': serializer.toJson<bool>(enabled),
      'priority': serializer.toJson<int>(priority),
      'configJson': serializer.toJson<String>(configJson),
      'sha256': serializer.toJson<String?>(sha256),
      'adult': serializer.toJson<bool>(adult),
      'installedAt': serializer.toJson<DateTime?>(installedAt),
    };
  }

  InstalledSourceRow copyWith({
    String? id,
    String? ecosystem,
    Value<String?> repoId = const Value.absent(),
    String? name,
    String? url,
    String? version,
    Value<String?> description = const Value.absent(),
    Value<String?> logo = const Value.absent(),
    bool? enabled,
    int? priority,
    String? configJson,
    Value<String?> sha256 = const Value.absent(),
    bool? adult,
    Value<DateTime?> installedAt = const Value.absent(),
  }) => InstalledSourceRow(
    id: id ?? this.id,
    ecosystem: ecosystem ?? this.ecosystem,
    repoId: repoId.present ? repoId.value : this.repoId,
    name: name ?? this.name,
    url: url ?? this.url,
    version: version ?? this.version,
    description: description.present ? description.value : this.description,
    logo: logo.present ? logo.value : this.logo,
    enabled: enabled ?? this.enabled,
    priority: priority ?? this.priority,
    configJson: configJson ?? this.configJson,
    sha256: sha256.present ? sha256.value : this.sha256,
    adult: adult ?? this.adult,
    installedAt: installedAt.present ? installedAt.value : this.installedAt,
  );
  InstalledSourceRow copyWithCompanion(InstalledSourcesCompanion data) {
    return InstalledSourceRow(
      id: data.id.present ? data.id.value : this.id,
      ecosystem: data.ecosystem.present ? data.ecosystem.value : this.ecosystem,
      repoId: data.repoId.present ? data.repoId.value : this.repoId,
      name: data.name.present ? data.name.value : this.name,
      url: data.url.present ? data.url.value : this.url,
      version: data.version.present ? data.version.value : this.version,
      description: data.description.present
          ? data.description.value
          : this.description,
      logo: data.logo.present ? data.logo.value : this.logo,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      priority: data.priority.present ? data.priority.value : this.priority,
      configJson: data.configJson.present
          ? data.configJson.value
          : this.configJson,
      sha256: data.sha256.present ? data.sha256.value : this.sha256,
      adult: data.adult.present ? data.adult.value : this.adult,
      installedAt: data.installedAt.present
          ? data.installedAt.value
          : this.installedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InstalledSourceRow(')
          ..write('id: $id, ')
          ..write('ecosystem: $ecosystem, ')
          ..write('repoId: $repoId, ')
          ..write('name: $name, ')
          ..write('url: $url, ')
          ..write('version: $version, ')
          ..write('description: $description, ')
          ..write('logo: $logo, ')
          ..write('enabled: $enabled, ')
          ..write('priority: $priority, ')
          ..write('configJson: $configJson, ')
          ..write('sha256: $sha256, ')
          ..write('adult: $adult, ')
          ..write('installedAt: $installedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    ecosystem,
    repoId,
    name,
    url,
    version,
    description,
    logo,
    enabled,
    priority,
    configJson,
    sha256,
    adult,
    installedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InstalledSourceRow &&
          other.id == this.id &&
          other.ecosystem == this.ecosystem &&
          other.repoId == this.repoId &&
          other.name == this.name &&
          other.url == this.url &&
          other.version == this.version &&
          other.description == this.description &&
          other.logo == this.logo &&
          other.enabled == this.enabled &&
          other.priority == this.priority &&
          other.configJson == this.configJson &&
          other.sha256 == this.sha256 &&
          other.adult == this.adult &&
          other.installedAt == this.installedAt);
}

class InstalledSourcesCompanion extends UpdateCompanion<InstalledSourceRow> {
  final Value<String> id;
  final Value<String> ecosystem;
  final Value<String?> repoId;
  final Value<String> name;
  final Value<String> url;
  final Value<String> version;
  final Value<String?> description;
  final Value<String?> logo;
  final Value<bool> enabled;
  final Value<int> priority;
  final Value<String> configJson;
  final Value<String?> sha256;
  final Value<bool> adult;
  final Value<DateTime?> installedAt;
  final Value<int> rowid;
  const InstalledSourcesCompanion({
    this.id = const Value.absent(),
    this.ecosystem = const Value.absent(),
    this.repoId = const Value.absent(),
    this.name = const Value.absent(),
    this.url = const Value.absent(),
    this.version = const Value.absent(),
    this.description = const Value.absent(),
    this.logo = const Value.absent(),
    this.enabled = const Value.absent(),
    this.priority = const Value.absent(),
    this.configJson = const Value.absent(),
    this.sha256 = const Value.absent(),
    this.adult = const Value.absent(),
    this.installedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InstalledSourcesCompanion.insert({
    required String id,
    required String ecosystem,
    this.repoId = const Value.absent(),
    required String name,
    required String url,
    this.version = const Value.absent(),
    this.description = const Value.absent(),
    this.logo = const Value.absent(),
    this.enabled = const Value.absent(),
    this.priority = const Value.absent(),
    this.configJson = const Value.absent(),
    this.sha256 = const Value.absent(),
    this.adult = const Value.absent(),
    this.installedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       ecosystem = Value(ecosystem),
       name = Value(name),
       url = Value(url);
  static Insertable<InstalledSourceRow> custom({
    Expression<String>? id,
    Expression<String>? ecosystem,
    Expression<String>? repoId,
    Expression<String>? name,
    Expression<String>? url,
    Expression<String>? version,
    Expression<String>? description,
    Expression<String>? logo,
    Expression<bool>? enabled,
    Expression<int>? priority,
    Expression<String>? configJson,
    Expression<String>? sha256,
    Expression<bool>? adult,
    Expression<DateTime>? installedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ecosystem != null) 'ecosystem': ecosystem,
      if (repoId != null) 'repo_id': repoId,
      if (name != null) 'name': name,
      if (url != null) 'url': url,
      if (version != null) 'version': version,
      if (description != null) 'description': description,
      if (logo != null) 'logo': logo,
      if (enabled != null) 'enabled': enabled,
      if (priority != null) 'priority': priority,
      if (configJson != null) 'config_json': configJson,
      if (sha256 != null) 'sha256': sha256,
      if (adult != null) 'adult': adult,
      if (installedAt != null) 'installed_at': installedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InstalledSourcesCompanion copyWith({
    Value<String>? id,
    Value<String>? ecosystem,
    Value<String?>? repoId,
    Value<String>? name,
    Value<String>? url,
    Value<String>? version,
    Value<String?>? description,
    Value<String?>? logo,
    Value<bool>? enabled,
    Value<int>? priority,
    Value<String>? configJson,
    Value<String?>? sha256,
    Value<bool>? adult,
    Value<DateTime?>? installedAt,
    Value<int>? rowid,
  }) {
    return InstalledSourcesCompanion(
      id: id ?? this.id,
      ecosystem: ecosystem ?? this.ecosystem,
      repoId: repoId ?? this.repoId,
      name: name ?? this.name,
      url: url ?? this.url,
      version: version ?? this.version,
      description: description ?? this.description,
      logo: logo ?? this.logo,
      enabled: enabled ?? this.enabled,
      priority: priority ?? this.priority,
      configJson: configJson ?? this.configJson,
      sha256: sha256 ?? this.sha256,
      adult: adult ?? this.adult,
      installedAt: installedAt ?? this.installedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (ecosystem.present) {
      map['ecosystem'] = Variable<String>(ecosystem.value);
    }
    if (repoId.present) {
      map['repo_id'] = Variable<String>(repoId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (version.present) {
      map['version'] = Variable<String>(version.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (logo.present) {
      map['logo'] = Variable<String>(logo.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (configJson.present) {
      map['config_json'] = Variable<String>(configJson.value);
    }
    if (sha256.present) {
      map['sha256'] = Variable<String>(sha256.value);
    }
    if (adult.present) {
      map['adult'] = Variable<bool>(adult.value);
    }
    if (installedAt.present) {
      map['installed_at'] = Variable<DateTime>(installedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InstalledSourcesCompanion(')
          ..write('id: $id, ')
          ..write('ecosystem: $ecosystem, ')
          ..write('repoId: $repoId, ')
          ..write('name: $name, ')
          ..write('url: $url, ')
          ..write('version: $version, ')
          ..write('description: $description, ')
          ..write('logo: $logo, ')
          ..write('enabled: $enabled, ')
          ..write('priority: $priority, ')
          ..write('configJson: $configJson, ')
          ..write('sha256: $sha256, ')
          ..write('adult: $adult, ')
          ..write('installedAt: $installedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MediaCacheTable extends MediaCache
    with TableInfo<$MediaCacheTable, MediaCacheRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MediaCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
    'json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<DateTime> expiresAt = GeneratedColumn<DateTime>(
    'expires_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, json, expiresAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'media_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<MediaCacheRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('json')) {
      context.handle(
        _jsonMeta,
        json.isAcceptableOrUnknown(data['json']!, _jsonMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    } else if (isInserting) {
      context.missing(_expiresAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  MediaCacheRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MediaCacheRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      json: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json'],
      )!,
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}expires_at'],
      )!,
    );
  }

  @override
  $MediaCacheTable createAlias(String alias) {
    return $MediaCacheTable(attachedDatabase, alias);
  }
}

class MediaCacheRow extends DataClass implements Insertable<MediaCacheRow> {
  final String key;
  final String json;
  final DateTime expiresAt;
  const MediaCacheRow({
    required this.key,
    required this.json,
    required this.expiresAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['json'] = Variable<String>(json);
    map['expires_at'] = Variable<DateTime>(expiresAt);
    return map;
  }

  MediaCacheCompanion toCompanion(bool nullToAbsent) {
    return MediaCacheCompanion(
      key: Value(key),
      json: Value(json),
      expiresAt: Value(expiresAt),
    );
  }

  factory MediaCacheRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MediaCacheRow(
      key: serializer.fromJson<String>(json['key']),
      json: serializer.fromJson<String>(json['json']),
      expiresAt: serializer.fromJson<DateTime>(json['expiresAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'json': serializer.toJson<String>(json),
      'expiresAt': serializer.toJson<DateTime>(expiresAt),
    };
  }

  MediaCacheRow copyWith({String? key, String? json, DateTime? expiresAt}) =>
      MediaCacheRow(
        key: key ?? this.key,
        json: json ?? this.json,
        expiresAt: expiresAt ?? this.expiresAt,
      );
  MediaCacheRow copyWithCompanion(MediaCacheCompanion data) {
    return MediaCacheRow(
      key: data.key.present ? data.key.value : this.key,
      json: data.json.present ? data.json.value : this.json,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MediaCacheRow(')
          ..write('key: $key, ')
          ..write('json: $json, ')
          ..write('expiresAt: $expiresAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, json, expiresAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MediaCacheRow &&
          other.key == this.key &&
          other.json == this.json &&
          other.expiresAt == this.expiresAt);
}

class MediaCacheCompanion extends UpdateCompanion<MediaCacheRow> {
  final Value<String> key;
  final Value<String> json;
  final Value<DateTime> expiresAt;
  final Value<int> rowid;
  const MediaCacheCompanion({
    this.key = const Value.absent(),
    this.json = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MediaCacheCompanion.insert({
    required String key,
    required String json,
    required DateTime expiresAt,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       json = Value(json),
       expiresAt = Value(expiresAt);
  static Insertable<MediaCacheRow> custom({
    Expression<String>? key,
    Expression<String>? json,
    Expression<DateTime>? expiresAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (json != null) 'json': json,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MediaCacheCompanion copyWith({
    Value<String>? key,
    Value<String>? json,
    Value<DateTime>? expiresAt,
    Value<int>? rowid,
  }) {
    return MediaCacheCompanion(
      key: key ?? this.key,
      json: json ?? this.json,
      expiresAt: expiresAt ?? this.expiresAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(expiresAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MediaCacheCompanion(')
          ..write('key: $key, ')
          ..write('json: $json, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WatchHistoryTable extends WatchHistory
    with TableInfo<$WatchHistoryTable, WatchHistoryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WatchHistoryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _mediaIdMeta = const VerificationMeta(
    'mediaId',
  );
  @override
  late final GeneratedColumn<String> mediaId = GeneratedColumn<String>(
    'media_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('default'),
  );
  static const VerificationMeta _seasonMeta = const VerificationMeta('season');
  @override
  late final GeneratedColumn<int> season = GeneratedColumn<int>(
    'season',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _episodeMeta = const VerificationMeta(
    'episode',
  );
  @override
  late final GeneratedColumn<int> episode = GeneratedColumn<int>(
    'episode',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _positionMsMeta = const VerificationMeta(
    'positionMs',
  );
  @override
  late final GeneratedColumn<int> positionMs = GeneratedColumn<int>(
    'position_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _metaJsonMeta = const VerificationMeta(
    'metaJson',
  );
  @override
  late final GeneratedColumn<String> metaJson = GeneratedColumn<String>(
    'meta_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    mediaId,
    profileId,
    season,
    episode,
    positionMs,
    durationMs,
    updatedAt,
    metaJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'watch_history';
  @override
  VerificationContext validateIntegrity(
    Insertable<WatchHistoryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('media_id')) {
      context.handle(
        _mediaIdMeta,
        mediaId.isAcceptableOrUnknown(data['media_id']!, _mediaIdMeta),
      );
    } else if (isInserting) {
      context.missing(_mediaIdMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    }
    if (data.containsKey('season')) {
      context.handle(
        _seasonMeta,
        season.isAcceptableOrUnknown(data['season']!, _seasonMeta),
      );
    }
    if (data.containsKey('episode')) {
      context.handle(
        _episodeMeta,
        episode.isAcceptableOrUnknown(data['episode']!, _episodeMeta),
      );
    }
    if (data.containsKey('position_ms')) {
      context.handle(
        _positionMsMeta,
        positionMs.isAcceptableOrUnknown(data['position_ms']!, _positionMsMeta),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('meta_json')) {
      context.handle(
        _metaJsonMeta,
        metaJson.isAcceptableOrUnknown(data['meta_json']!, _metaJsonMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {mediaId, profileId, season, episode};
  @override
  WatchHistoryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WatchHistoryRow(
      mediaId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      season: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}season'],
      ),
      episode: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}episode'],
      ),
      positionMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position_ms'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      metaJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meta_json'],
      )!,
    );
  }

  @override
  $WatchHistoryTable createAlias(String alias) {
    return $WatchHistoryTable(attachedDatabase, alias);
  }
}

class WatchHistoryRow extends DataClass implements Insertable<WatchHistoryRow> {
  final String mediaId;
  final String profileId;
  final int? season;
  final int? episode;
  final int positionMs;
  final int durationMs;
  final DateTime updatedAt;

  /// Denormalised card data so Continue Watching renders offline.
  final String metaJson;
  const WatchHistoryRow({
    required this.mediaId,
    required this.profileId,
    this.season,
    this.episode,
    required this.positionMs,
    required this.durationMs,
    required this.updatedAt,
    required this.metaJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['media_id'] = Variable<String>(mediaId);
    map['profile_id'] = Variable<String>(profileId);
    if (!nullToAbsent || season != null) {
      map['season'] = Variable<int>(season);
    }
    if (!nullToAbsent || episode != null) {
      map['episode'] = Variable<int>(episode);
    }
    map['position_ms'] = Variable<int>(positionMs);
    map['duration_ms'] = Variable<int>(durationMs);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['meta_json'] = Variable<String>(metaJson);
    return map;
  }

  WatchHistoryCompanion toCompanion(bool nullToAbsent) {
    return WatchHistoryCompanion(
      mediaId: Value(mediaId),
      profileId: Value(profileId),
      season: season == null && nullToAbsent
          ? const Value.absent()
          : Value(season),
      episode: episode == null && nullToAbsent
          ? const Value.absent()
          : Value(episode),
      positionMs: Value(positionMs),
      durationMs: Value(durationMs),
      updatedAt: Value(updatedAt),
      metaJson: Value(metaJson),
    );
  }

  factory WatchHistoryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WatchHistoryRow(
      mediaId: serializer.fromJson<String>(json['mediaId']),
      profileId: serializer.fromJson<String>(json['profileId']),
      season: serializer.fromJson<int?>(json['season']),
      episode: serializer.fromJson<int?>(json['episode']),
      positionMs: serializer.fromJson<int>(json['positionMs']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      metaJson: serializer.fromJson<String>(json['metaJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'mediaId': serializer.toJson<String>(mediaId),
      'profileId': serializer.toJson<String>(profileId),
      'season': serializer.toJson<int?>(season),
      'episode': serializer.toJson<int?>(episode),
      'positionMs': serializer.toJson<int>(positionMs),
      'durationMs': serializer.toJson<int>(durationMs),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'metaJson': serializer.toJson<String>(metaJson),
    };
  }

  WatchHistoryRow copyWith({
    String? mediaId,
    String? profileId,
    Value<int?> season = const Value.absent(),
    Value<int?> episode = const Value.absent(),
    int? positionMs,
    int? durationMs,
    DateTime? updatedAt,
    String? metaJson,
  }) => WatchHistoryRow(
    mediaId: mediaId ?? this.mediaId,
    profileId: profileId ?? this.profileId,
    season: season.present ? season.value : this.season,
    episode: episode.present ? episode.value : this.episode,
    positionMs: positionMs ?? this.positionMs,
    durationMs: durationMs ?? this.durationMs,
    updatedAt: updatedAt ?? this.updatedAt,
    metaJson: metaJson ?? this.metaJson,
  );
  WatchHistoryRow copyWithCompanion(WatchHistoryCompanion data) {
    return WatchHistoryRow(
      mediaId: data.mediaId.present ? data.mediaId.value : this.mediaId,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      season: data.season.present ? data.season.value : this.season,
      episode: data.episode.present ? data.episode.value : this.episode,
      positionMs: data.positionMs.present
          ? data.positionMs.value
          : this.positionMs,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      metaJson: data.metaJson.present ? data.metaJson.value : this.metaJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WatchHistoryRow(')
          ..write('mediaId: $mediaId, ')
          ..write('profileId: $profileId, ')
          ..write('season: $season, ')
          ..write('episode: $episode, ')
          ..write('positionMs: $positionMs, ')
          ..write('durationMs: $durationMs, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('metaJson: $metaJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    mediaId,
    profileId,
    season,
    episode,
    positionMs,
    durationMs,
    updatedAt,
    metaJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WatchHistoryRow &&
          other.mediaId == this.mediaId &&
          other.profileId == this.profileId &&
          other.season == this.season &&
          other.episode == this.episode &&
          other.positionMs == this.positionMs &&
          other.durationMs == this.durationMs &&
          other.updatedAt == this.updatedAt &&
          other.metaJson == this.metaJson);
}

class WatchHistoryCompanion extends UpdateCompanion<WatchHistoryRow> {
  final Value<String> mediaId;
  final Value<String> profileId;
  final Value<int?> season;
  final Value<int?> episode;
  final Value<int> positionMs;
  final Value<int> durationMs;
  final Value<DateTime> updatedAt;
  final Value<String> metaJson;
  final Value<int> rowid;
  const WatchHistoryCompanion({
    this.mediaId = const Value.absent(),
    this.profileId = const Value.absent(),
    this.season = const Value.absent(),
    this.episode = const Value.absent(),
    this.positionMs = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.metaJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WatchHistoryCompanion.insert({
    required String mediaId,
    this.profileId = const Value.absent(),
    this.season = const Value.absent(),
    this.episode = const Value.absent(),
    this.positionMs = const Value.absent(),
    this.durationMs = const Value.absent(),
    required DateTime updatedAt,
    this.metaJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : mediaId = Value(mediaId),
       updatedAt = Value(updatedAt);
  static Insertable<WatchHistoryRow> custom({
    Expression<String>? mediaId,
    Expression<String>? profileId,
    Expression<int>? season,
    Expression<int>? episode,
    Expression<int>? positionMs,
    Expression<int>? durationMs,
    Expression<DateTime>? updatedAt,
    Expression<String>? metaJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (mediaId != null) 'media_id': mediaId,
      if (profileId != null) 'profile_id': profileId,
      if (season != null) 'season': season,
      if (episode != null) 'episode': episode,
      if (positionMs != null) 'position_ms': positionMs,
      if (durationMs != null) 'duration_ms': durationMs,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (metaJson != null) 'meta_json': metaJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WatchHistoryCompanion copyWith({
    Value<String>? mediaId,
    Value<String>? profileId,
    Value<int?>? season,
    Value<int?>? episode,
    Value<int>? positionMs,
    Value<int>? durationMs,
    Value<DateTime>? updatedAt,
    Value<String>? metaJson,
    Value<int>? rowid,
  }) {
    return WatchHistoryCompanion(
      mediaId: mediaId ?? this.mediaId,
      profileId: profileId ?? this.profileId,
      season: season ?? this.season,
      episode: episode ?? this.episode,
      positionMs: positionMs ?? this.positionMs,
      durationMs: durationMs ?? this.durationMs,
      updatedAt: updatedAt ?? this.updatedAt,
      metaJson: metaJson ?? this.metaJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (mediaId.present) {
      map['media_id'] = Variable<String>(mediaId.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (season.present) {
      map['season'] = Variable<int>(season.value);
    }
    if (episode.present) {
      map['episode'] = Variable<int>(episode.value);
    }
    if (positionMs.present) {
      map['position_ms'] = Variable<int>(positionMs.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (metaJson.present) {
      map['meta_json'] = Variable<String>(metaJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WatchHistoryCompanion(')
          ..write('mediaId: $mediaId, ')
          ..write('profileId: $profileId, ')
          ..write('season: $season, ')
          ..write('episode: $episode, ')
          ..write('positionMs: $positionMs, ')
          ..write('durationMs: $durationMs, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('metaJson: $metaJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LibraryEntriesTable extends LibraryEntries
    with TableInfo<$LibraryEntriesTable, LibraryEntryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LibraryEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _mediaIdMeta = const VerificationMeta(
    'mediaId',
  );
  @override
  late final GeneratedColumn<String> mediaId = GeneratedColumn<String>(
    'media_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('default'),
  );
  static const VerificationMeta _listNameMeta = const VerificationMeta(
    'listName',
  );
  @override
  late final GeneratedColumn<String> listName = GeneratedColumn<String>(
    'list_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _metaJsonMeta = const VerificationMeta(
    'metaJson',
  );
  @override
  late final GeneratedColumn<String> metaJson = GeneratedColumn<String>(
    'meta_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    mediaId,
    profileId,
    listName,
    metaJson,
    addedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'library_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<LibraryEntryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('media_id')) {
      context.handle(
        _mediaIdMeta,
        mediaId.isAcceptableOrUnknown(data['media_id']!, _mediaIdMeta),
      );
    } else if (isInserting) {
      context.missing(_mediaIdMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    }
    if (data.containsKey('list_name')) {
      context.handle(
        _listNameMeta,
        listName.isAcceptableOrUnknown(data['list_name']!, _listNameMeta),
      );
    } else if (isInserting) {
      context.missing(_listNameMeta);
    }
    if (data.containsKey('meta_json')) {
      context.handle(
        _metaJsonMeta,
        metaJson.isAcceptableOrUnknown(data['meta_json']!, _metaJsonMeta),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {mediaId, profileId, listName};
  @override
  LibraryEntryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LibraryEntryRow(
      mediaId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      listName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}list_name'],
      )!,
      metaJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meta_json'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $LibraryEntriesTable createAlias(String alias) {
    return $LibraryEntriesTable(attachedDatabase, alias);
  }
}

class LibraryEntryRow extends DataClass implements Insertable<LibraryEntryRow> {
  final String mediaId;
  final String profileId;
  final String listName;
  final String metaJson;
  final DateTime addedAt;
  const LibraryEntryRow({
    required this.mediaId,
    required this.profileId,
    required this.listName,
    required this.metaJson,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['media_id'] = Variable<String>(mediaId);
    map['profile_id'] = Variable<String>(profileId);
    map['list_name'] = Variable<String>(listName);
    map['meta_json'] = Variable<String>(metaJson);
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  LibraryEntriesCompanion toCompanion(bool nullToAbsent) {
    return LibraryEntriesCompanion(
      mediaId: Value(mediaId),
      profileId: Value(profileId),
      listName: Value(listName),
      metaJson: Value(metaJson),
      addedAt: Value(addedAt),
    );
  }

  factory LibraryEntryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LibraryEntryRow(
      mediaId: serializer.fromJson<String>(json['mediaId']),
      profileId: serializer.fromJson<String>(json['profileId']),
      listName: serializer.fromJson<String>(json['listName']),
      metaJson: serializer.fromJson<String>(json['metaJson']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'mediaId': serializer.toJson<String>(mediaId),
      'profileId': serializer.toJson<String>(profileId),
      'listName': serializer.toJson<String>(listName),
      'metaJson': serializer.toJson<String>(metaJson),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  LibraryEntryRow copyWith({
    String? mediaId,
    String? profileId,
    String? listName,
    String? metaJson,
    DateTime? addedAt,
  }) => LibraryEntryRow(
    mediaId: mediaId ?? this.mediaId,
    profileId: profileId ?? this.profileId,
    listName: listName ?? this.listName,
    metaJson: metaJson ?? this.metaJson,
    addedAt: addedAt ?? this.addedAt,
  );
  LibraryEntryRow copyWithCompanion(LibraryEntriesCompanion data) {
    return LibraryEntryRow(
      mediaId: data.mediaId.present ? data.mediaId.value : this.mediaId,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      listName: data.listName.present ? data.listName.value : this.listName,
      metaJson: data.metaJson.present ? data.metaJson.value : this.metaJson,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LibraryEntryRow(')
          ..write('mediaId: $mediaId, ')
          ..write('profileId: $profileId, ')
          ..write('listName: $listName, ')
          ..write('metaJson: $metaJson, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(mediaId, profileId, listName, metaJson, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LibraryEntryRow &&
          other.mediaId == this.mediaId &&
          other.profileId == this.profileId &&
          other.listName == this.listName &&
          other.metaJson == this.metaJson &&
          other.addedAt == this.addedAt);
}

class LibraryEntriesCompanion extends UpdateCompanion<LibraryEntryRow> {
  final Value<String> mediaId;
  final Value<String> profileId;
  final Value<String> listName;
  final Value<String> metaJson;
  final Value<DateTime> addedAt;
  final Value<int> rowid;
  const LibraryEntriesCompanion({
    this.mediaId = const Value.absent(),
    this.profileId = const Value.absent(),
    this.listName = const Value.absent(),
    this.metaJson = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LibraryEntriesCompanion.insert({
    required String mediaId,
    this.profileId = const Value.absent(),
    required String listName,
    this.metaJson = const Value.absent(),
    required DateTime addedAt,
    this.rowid = const Value.absent(),
  }) : mediaId = Value(mediaId),
       listName = Value(listName),
       addedAt = Value(addedAt);
  static Insertable<LibraryEntryRow> custom({
    Expression<String>? mediaId,
    Expression<String>? profileId,
    Expression<String>? listName,
    Expression<String>? metaJson,
    Expression<DateTime>? addedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (mediaId != null) 'media_id': mediaId,
      if (profileId != null) 'profile_id': profileId,
      if (listName != null) 'list_name': listName,
      if (metaJson != null) 'meta_json': metaJson,
      if (addedAt != null) 'added_at': addedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LibraryEntriesCompanion copyWith({
    Value<String>? mediaId,
    Value<String>? profileId,
    Value<String>? listName,
    Value<String>? metaJson,
    Value<DateTime>? addedAt,
    Value<int>? rowid,
  }) {
    return LibraryEntriesCompanion(
      mediaId: mediaId ?? this.mediaId,
      profileId: profileId ?? this.profileId,
      listName: listName ?? this.listName,
      metaJson: metaJson ?? this.metaJson,
      addedAt: addedAt ?? this.addedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (mediaId.present) {
      map['media_id'] = Variable<String>(mediaId.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (listName.present) {
      map['list_name'] = Variable<String>(listName.value);
    }
    if (metaJson.present) {
      map['meta_json'] = Variable<String>(metaJson.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LibraryEntriesCompanion(')
          ..write('mediaId: $mediaId, ')
          ..write('profileId: $profileId, ')
          ..write('listName: $listName, ')
          ..write('metaJson: $metaJson, ')
          ..write('addedAt: $addedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProfilesTable extends Profiles
    with TableInfo<$ProfilesTable, ProfileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _avatarMeta = const VerificationMeta('avatar');
  @override
  late final GeneratedColumn<String> avatar = GeneratedColumn<String>(
    'avatar',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pinHashMeta = const VerificationMeta(
    'pinHash',
  );
  @override
  late final GeneratedColumn<String> pinHash = GeneratedColumn<String>(
    'pin_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isKidsMeta = const VerificationMeta('isKids');
  @override
  late final GeneratedColumn<bool> isKids = GeneratedColumn<bool>(
    'is_kids',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_kids" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, avatar, pinHash, isKids];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProfileRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('avatar')) {
      context.handle(
        _avatarMeta,
        avatar.isAcceptableOrUnknown(data['avatar']!, _avatarMeta),
      );
    }
    if (data.containsKey('pin_hash')) {
      context.handle(
        _pinHashMeta,
        pinHash.isAcceptableOrUnknown(data['pin_hash']!, _pinHashMeta),
      );
    }
    if (data.containsKey('is_kids')) {
      context.handle(
        _isKidsMeta,
        isKids.isAcceptableOrUnknown(data['is_kids']!, _isKidsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProfileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProfileRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      avatar: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}avatar'],
      ),
      pinHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pin_hash'],
      ),
      isKids: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_kids'],
      )!,
    );
  }

  @override
  $ProfilesTable createAlias(String alias) {
    return $ProfilesTable(attachedDatabase, alias);
  }
}

class ProfileRow extends DataClass implements Insertable<ProfileRow> {
  final String id;
  final String name;
  final String? avatar;
  final String? pinHash;
  final bool isKids;
  const ProfileRow({
    required this.id,
    required this.name,
    this.avatar,
    this.pinHash,
    required this.isKids,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || avatar != null) {
      map['avatar'] = Variable<String>(avatar);
    }
    if (!nullToAbsent || pinHash != null) {
      map['pin_hash'] = Variable<String>(pinHash);
    }
    map['is_kids'] = Variable<bool>(isKids);
    return map;
  }

  ProfilesCompanion toCompanion(bool nullToAbsent) {
    return ProfilesCompanion(
      id: Value(id),
      name: Value(name),
      avatar: avatar == null && nullToAbsent
          ? const Value.absent()
          : Value(avatar),
      pinHash: pinHash == null && nullToAbsent
          ? const Value.absent()
          : Value(pinHash),
      isKids: Value(isKids),
    );
  }

  factory ProfileRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProfileRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      avatar: serializer.fromJson<String?>(json['avatar']),
      pinHash: serializer.fromJson<String?>(json['pinHash']),
      isKids: serializer.fromJson<bool>(json['isKids']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'avatar': serializer.toJson<String?>(avatar),
      'pinHash': serializer.toJson<String?>(pinHash),
      'isKids': serializer.toJson<bool>(isKids),
    };
  }

  ProfileRow copyWith({
    String? id,
    String? name,
    Value<String?> avatar = const Value.absent(),
    Value<String?> pinHash = const Value.absent(),
    bool? isKids,
  }) => ProfileRow(
    id: id ?? this.id,
    name: name ?? this.name,
    avatar: avatar.present ? avatar.value : this.avatar,
    pinHash: pinHash.present ? pinHash.value : this.pinHash,
    isKids: isKids ?? this.isKids,
  );
  ProfileRow copyWithCompanion(ProfilesCompanion data) {
    return ProfileRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      avatar: data.avatar.present ? data.avatar.value : this.avatar,
      pinHash: data.pinHash.present ? data.pinHash.value : this.pinHash,
      isKids: data.isKids.present ? data.isKids.value : this.isKids,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProfileRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('avatar: $avatar, ')
          ..write('pinHash: $pinHash, ')
          ..write('isKids: $isKids')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, avatar, pinHash, isKids);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProfileRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.avatar == this.avatar &&
          other.pinHash == this.pinHash &&
          other.isKids == this.isKids);
}

class ProfilesCompanion extends UpdateCompanion<ProfileRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> avatar;
  final Value<String?> pinHash;
  final Value<bool> isKids;
  final Value<int> rowid;
  const ProfilesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.avatar = const Value.absent(),
    this.pinHash = const Value.absent(),
    this.isKids = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProfilesCompanion.insert({
    required String id,
    required String name,
    this.avatar = const Value.absent(),
    this.pinHash = const Value.absent(),
    this.isKids = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<ProfileRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? avatar,
    Expression<String>? pinHash,
    Expression<bool>? isKids,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (avatar != null) 'avatar': avatar,
      if (pinHash != null) 'pin_hash': pinHash,
      if (isKids != null) 'is_kids': isKids,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProfilesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? avatar,
    Value<String?>? pinHash,
    Value<bool>? isKids,
    Value<int>? rowid,
  }) {
    return ProfilesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      pinHash: pinHash ?? this.pinHash,
      isKids: isKids ?? this.isKids,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (avatar.present) {
      map['avatar'] = Variable<String>(avatar.value);
    }
    if (pinHash.present) {
      map['pin_hash'] = Variable<String>(pinHash.value);
    }
    if (isKids.present) {
      map['is_kids'] = Variable<bool>(isKids.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProfilesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('avatar: $avatar, ')
          ..write('pinHash: $pinHash, ')
          ..write('isKids: $isKids, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProviderHealthTableTable extends ProviderHealthTable
    with TableInfo<$ProviderHealthTableTable, ProviderHealthRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProviderHealthTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sourceKeyMeta = const VerificationMeta(
    'sourceKey',
  );
  @override
  late final GeneratedColumn<String> sourceKey = GeneratedColumn<String>(
    'source_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _successCountMeta = const VerificationMeta(
    'successCount',
  );
  @override
  late final GeneratedColumn<int> successCount = GeneratedColumn<int>(
    'success_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _failCountMeta = const VerificationMeta(
    'failCount',
  );
  @override
  late final GeneratedColumn<int> failCount = GeneratedColumn<int>(
    'fail_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _avgLatencyMsMeta = const VerificationMeta(
    'avgLatencyMs',
  );
  @override
  late final GeneratedColumn<double> avgLatencyMs = GeneratedColumn<double>(
    'avg_latency_ms',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastCheckedMeta = const VerificationMeta(
    'lastChecked',
  );
  @override
  late final GeneratedColumn<DateTime> lastChecked = GeneratedColumn<DateTime>(
    'last_checked',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    sourceKey,
    successCount,
    failCount,
    avgLatencyMs,
    lastChecked,
    lastError,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'provider_health_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProviderHealthRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('source_key')) {
      context.handle(
        _sourceKeyMeta,
        sourceKey.isAcceptableOrUnknown(data['source_key']!, _sourceKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceKeyMeta);
    }
    if (data.containsKey('success_count')) {
      context.handle(
        _successCountMeta,
        successCount.isAcceptableOrUnknown(
          data['success_count']!,
          _successCountMeta,
        ),
      );
    }
    if (data.containsKey('fail_count')) {
      context.handle(
        _failCountMeta,
        failCount.isAcceptableOrUnknown(data['fail_count']!, _failCountMeta),
      );
    }
    if (data.containsKey('avg_latency_ms')) {
      context.handle(
        _avgLatencyMsMeta,
        avgLatencyMs.isAcceptableOrUnknown(
          data['avg_latency_ms']!,
          _avgLatencyMsMeta,
        ),
      );
    }
    if (data.containsKey('last_checked')) {
      context.handle(
        _lastCheckedMeta,
        lastChecked.isAcceptableOrUnknown(
          data['last_checked']!,
          _lastCheckedMeta,
        ),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sourceKey};
  @override
  ProviderHealthRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProviderHealthRow(
      sourceKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_key'],
      )!,
      successCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}success_count'],
      )!,
      failCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fail_count'],
      )!,
      avgLatencyMs: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}avg_latency_ms'],
      )!,
      lastChecked: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_checked'],
      ),
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
    );
  }

  @override
  $ProviderHealthTableTable createAlias(String alias) {
    return $ProviderHealthTableTable(attachedDatabase, alias);
  }
}

class ProviderHealthRow extends DataClass
    implements Insertable<ProviderHealthRow> {
  final String sourceKey;
  final int successCount;
  final int failCount;
  final double avgLatencyMs;
  final DateTime? lastChecked;
  final String? lastError;
  const ProviderHealthRow({
    required this.sourceKey,
    required this.successCount,
    required this.failCount,
    required this.avgLatencyMs,
    this.lastChecked,
    this.lastError,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['source_key'] = Variable<String>(sourceKey);
    map['success_count'] = Variable<int>(successCount);
    map['fail_count'] = Variable<int>(failCount);
    map['avg_latency_ms'] = Variable<double>(avgLatencyMs);
    if (!nullToAbsent || lastChecked != null) {
      map['last_checked'] = Variable<DateTime>(lastChecked);
    }
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    return map;
  }

  ProviderHealthTableCompanion toCompanion(bool nullToAbsent) {
    return ProviderHealthTableCompanion(
      sourceKey: Value(sourceKey),
      successCount: Value(successCount),
      failCount: Value(failCount),
      avgLatencyMs: Value(avgLatencyMs),
      lastChecked: lastChecked == null && nullToAbsent
          ? const Value.absent()
          : Value(lastChecked),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
    );
  }

  factory ProviderHealthRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProviderHealthRow(
      sourceKey: serializer.fromJson<String>(json['sourceKey']),
      successCount: serializer.fromJson<int>(json['successCount']),
      failCount: serializer.fromJson<int>(json['failCount']),
      avgLatencyMs: serializer.fromJson<double>(json['avgLatencyMs']),
      lastChecked: serializer.fromJson<DateTime?>(json['lastChecked']),
      lastError: serializer.fromJson<String?>(json['lastError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sourceKey': serializer.toJson<String>(sourceKey),
      'successCount': serializer.toJson<int>(successCount),
      'failCount': serializer.toJson<int>(failCount),
      'avgLatencyMs': serializer.toJson<double>(avgLatencyMs),
      'lastChecked': serializer.toJson<DateTime?>(lastChecked),
      'lastError': serializer.toJson<String?>(lastError),
    };
  }

  ProviderHealthRow copyWith({
    String? sourceKey,
    int? successCount,
    int? failCount,
    double? avgLatencyMs,
    Value<DateTime?> lastChecked = const Value.absent(),
    Value<String?> lastError = const Value.absent(),
  }) => ProviderHealthRow(
    sourceKey: sourceKey ?? this.sourceKey,
    successCount: successCount ?? this.successCount,
    failCount: failCount ?? this.failCount,
    avgLatencyMs: avgLatencyMs ?? this.avgLatencyMs,
    lastChecked: lastChecked.present ? lastChecked.value : this.lastChecked,
    lastError: lastError.present ? lastError.value : this.lastError,
  );
  ProviderHealthRow copyWithCompanion(ProviderHealthTableCompanion data) {
    return ProviderHealthRow(
      sourceKey: data.sourceKey.present ? data.sourceKey.value : this.sourceKey,
      successCount: data.successCount.present
          ? data.successCount.value
          : this.successCount,
      failCount: data.failCount.present ? data.failCount.value : this.failCount,
      avgLatencyMs: data.avgLatencyMs.present
          ? data.avgLatencyMs.value
          : this.avgLatencyMs,
      lastChecked: data.lastChecked.present
          ? data.lastChecked.value
          : this.lastChecked,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProviderHealthRow(')
          ..write('sourceKey: $sourceKey, ')
          ..write('successCount: $successCount, ')
          ..write('failCount: $failCount, ')
          ..write('avgLatencyMs: $avgLatencyMs, ')
          ..write('lastChecked: $lastChecked, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    sourceKey,
    successCount,
    failCount,
    avgLatencyMs,
    lastChecked,
    lastError,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProviderHealthRow &&
          other.sourceKey == this.sourceKey &&
          other.successCount == this.successCount &&
          other.failCount == this.failCount &&
          other.avgLatencyMs == this.avgLatencyMs &&
          other.lastChecked == this.lastChecked &&
          other.lastError == this.lastError);
}

class ProviderHealthTableCompanion extends UpdateCompanion<ProviderHealthRow> {
  final Value<String> sourceKey;
  final Value<int> successCount;
  final Value<int> failCount;
  final Value<double> avgLatencyMs;
  final Value<DateTime?> lastChecked;
  final Value<String?> lastError;
  final Value<int> rowid;
  const ProviderHealthTableCompanion({
    this.sourceKey = const Value.absent(),
    this.successCount = const Value.absent(),
    this.failCount = const Value.absent(),
    this.avgLatencyMs = const Value.absent(),
    this.lastChecked = const Value.absent(),
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProviderHealthTableCompanion.insert({
    required String sourceKey,
    this.successCount = const Value.absent(),
    this.failCount = const Value.absent(),
    this.avgLatencyMs = const Value.absent(),
    this.lastChecked = const Value.absent(),
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : sourceKey = Value(sourceKey);
  static Insertable<ProviderHealthRow> custom({
    Expression<String>? sourceKey,
    Expression<int>? successCount,
    Expression<int>? failCount,
    Expression<double>? avgLatencyMs,
    Expression<DateTime>? lastChecked,
    Expression<String>? lastError,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sourceKey != null) 'source_key': sourceKey,
      if (successCount != null) 'success_count': successCount,
      if (failCount != null) 'fail_count': failCount,
      if (avgLatencyMs != null) 'avg_latency_ms': avgLatencyMs,
      if (lastChecked != null) 'last_checked': lastChecked,
      if (lastError != null) 'last_error': lastError,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProviderHealthTableCompanion copyWith({
    Value<String>? sourceKey,
    Value<int>? successCount,
    Value<int>? failCount,
    Value<double>? avgLatencyMs,
    Value<DateTime?>? lastChecked,
    Value<String?>? lastError,
    Value<int>? rowid,
  }) {
    return ProviderHealthTableCompanion(
      sourceKey: sourceKey ?? this.sourceKey,
      successCount: successCount ?? this.successCount,
      failCount: failCount ?? this.failCount,
      avgLatencyMs: avgLatencyMs ?? this.avgLatencyMs,
      lastChecked: lastChecked ?? this.lastChecked,
      lastError: lastError ?? this.lastError,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sourceKey.present) {
      map['source_key'] = Variable<String>(sourceKey.value);
    }
    if (successCount.present) {
      map['success_count'] = Variable<int>(successCount.value);
    }
    if (failCount.present) {
      map['fail_count'] = Variable<int>(failCount.value);
    }
    if (avgLatencyMs.present) {
      map['avg_latency_ms'] = Variable<double>(avgLatencyMs.value);
    }
    if (lastChecked.present) {
      map['last_checked'] = Variable<DateTime>(lastChecked.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProviderHealthTableCompanion(')
          ..write('sourceKey: $sourceKey, ')
          ..write('successCount: $successCount, ')
          ..write('failCount: $failCount, ')
          ..write('avgLatencyMs: $avgLatencyMs, ')
          ..write('lastChecked: $lastChecked, ')
          ..write('lastError: $lastError, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueJsonMeta = const VerificationMeta(
    'valueJson',
  );
  @override
  late final GeneratedColumn<String> valueJson = GeneratedColumn<String>(
    'value_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, valueJson];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSettingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value_json')) {
      context.handle(
        _valueJsonMeta,
        valueJson.isAcceptableOrUnknown(data['value_json']!, _valueJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_valueJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppSettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSettingRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      valueJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value_json'],
      )!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSettingRow extends DataClass implements Insertable<AppSettingRow> {
  final String key;
  final String valueJson;
  const AppSettingRow({required this.key, required this.valueJson});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value_json'] = Variable<String>(valueJson);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(key: Value(key), valueJson: Value(valueJson));
  }

  factory AppSettingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSettingRow(
      key: serializer.fromJson<String>(json['key']),
      valueJson: serializer.fromJson<String>(json['valueJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'valueJson': serializer.toJson<String>(valueJson),
    };
  }

  AppSettingRow copyWith({String? key, String? valueJson}) => AppSettingRow(
    key: key ?? this.key,
    valueJson: valueJson ?? this.valueJson,
  );
  AppSettingRow copyWithCompanion(AppSettingsCompanion data) {
    return AppSettingRow(
      key: data.key.present ? data.key.value : this.key,
      valueJson: data.valueJson.present ? data.valueJson.value : this.valueJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingRow(')
          ..write('key: $key, ')
          ..write('valueJson: $valueJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, valueJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSettingRow &&
          other.key == this.key &&
          other.valueJson == this.valueJson);
}

class AppSettingsCompanion extends UpdateCompanion<AppSettingRow> {
  final Value<String> key;
  final Value<String> valueJson;
  final Value<int> rowid;
  const AppSettingsCompanion({
    this.key = const Value.absent(),
    this.valueJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    required String key,
    required String valueJson,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       valueJson = Value(valueJson);
  static Insertable<AppSettingRow> custom({
    Expression<String>? key,
    Expression<String>? valueJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (valueJson != null) 'value_json': valueJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? valueJson,
    Value<int>? rowid,
  }) {
    return AppSettingsCompanion(
      key: key ?? this.key,
      valueJson: valueJson ?? this.valueJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (valueJson.present) {
      map['value_json'] = Variable<String>(valueJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('key: $key, ')
          ..write('valueJson: $valueJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $IdMappingsTable extends IdMappings
    with TableInfo<$IdMappingsTable, IdMappingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $IdMappingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
    'json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta(
    'fetchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> fetchedAt = GeneratedColumn<DateTime>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, json, fetchedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'id_mappings';
  @override
  VerificationContext validateIntegrity(
    Insertable<IdMappingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('json')) {
      context.handle(
        _jsonMeta,
        json.isAcceptableOrUnknown(data['json']!, _jsonMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetchedAtMeta,
        fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  IdMappingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return IdMappingRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      json: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json'],
      )!,
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fetched_at'],
      )!,
    );
  }

  @override
  $IdMappingsTable createAlias(String alias) {
    return $IdMappingsTable(attachedDatabase, alias);
  }
}

class IdMappingRow extends DataClass implements Insertable<IdMappingRow> {
  final String key;
  final String json;
  final DateTime fetchedAt;
  const IdMappingRow({
    required this.key,
    required this.json,
    required this.fetchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['json'] = Variable<String>(json);
    map['fetched_at'] = Variable<DateTime>(fetchedAt);
    return map;
  }

  IdMappingsCompanion toCompanion(bool nullToAbsent) {
    return IdMappingsCompanion(
      key: Value(key),
      json: Value(json),
      fetchedAt: Value(fetchedAt),
    );
  }

  factory IdMappingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return IdMappingRow(
      key: serializer.fromJson<String>(json['key']),
      json: serializer.fromJson<String>(json['json']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'json': serializer.toJson<String>(json),
      'fetchedAt': serializer.toJson<DateTime>(fetchedAt),
    };
  }

  IdMappingRow copyWith({String? key, String? json, DateTime? fetchedAt}) =>
      IdMappingRow(
        key: key ?? this.key,
        json: json ?? this.json,
        fetchedAt: fetchedAt ?? this.fetchedAt,
      );
  IdMappingRow copyWithCompanion(IdMappingsCompanion data) {
    return IdMappingRow(
      key: data.key.present ? data.key.value : this.key,
      json: data.json.present ? data.json.value : this.json,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('IdMappingRow(')
          ..write('key: $key, ')
          ..write('json: $json, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, json, fetchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IdMappingRow &&
          other.key == this.key &&
          other.json == this.json &&
          other.fetchedAt == this.fetchedAt);
}

class IdMappingsCompanion extends UpdateCompanion<IdMappingRow> {
  final Value<String> key;
  final Value<String> json;
  final Value<DateTime> fetchedAt;
  final Value<int> rowid;
  const IdMappingsCompanion({
    this.key = const Value.absent(),
    this.json = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  IdMappingsCompanion.insert({
    required String key,
    required String json,
    required DateTime fetchedAt,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       json = Value(json),
       fetchedAt = Value(fetchedAt);
  static Insertable<IdMappingRow> custom({
    Expression<String>? key,
    Expression<String>? json,
    Expression<DateTime>? fetchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (json != null) 'json': json,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  IdMappingsCompanion copyWith({
    Value<String>? key,
    Value<String>? json,
    Value<DateTime>? fetchedAt,
    Value<int>? rowid,
  }) {
    return IdMappingsCompanion(
      key: key ?? this.key,
      json: json ?? this.json,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('IdMappingsCompanion(')
          ..write('key: $key, ')
          ..write('json: $json, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AeroDatabase extends GeneratedDatabase {
  _$AeroDatabase(QueryExecutor e) : super(e);
  $AeroDatabaseManager get managers => $AeroDatabaseManager(this);
  late final $RepositoriesTable repositories = $RepositoriesTable(this);
  late final $InstalledSourcesTable installedSources = $InstalledSourcesTable(
    this,
  );
  late final $MediaCacheTable mediaCache = $MediaCacheTable(this);
  late final $WatchHistoryTable watchHistory = $WatchHistoryTable(this);
  late final $LibraryEntriesTable libraryEntries = $LibraryEntriesTable(this);
  late final $ProfilesTable profiles = $ProfilesTable(this);
  late final $ProviderHealthTableTable providerHealthTable =
      $ProviderHealthTableTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final $IdMappingsTable idMappings = $IdMappingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    repositories,
    installedSources,
    mediaCache,
    watchHistory,
    libraryEntries,
    profiles,
    providerHealthTable,
    appSettings,
    idMappings,
  ];
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}

typedef $$RepositoriesTableCreateCompanionBuilder =
    RepositoriesCompanion Function({
      required String id,
      required String ecosystem,
      required String url,
      required String name,
      Value<DateTime?> lastSync,
      Value<bool> enabled,
      Value<int> rowid,
    });
typedef $$RepositoriesTableUpdateCompanionBuilder =
    RepositoriesCompanion Function({
      Value<String> id,
      Value<String> ecosystem,
      Value<String> url,
      Value<String> name,
      Value<DateTime?> lastSync,
      Value<bool> enabled,
      Value<int> rowid,
    });

class $$RepositoriesTableFilterComposer
    extends Composer<_$AeroDatabase, $RepositoriesTable> {
  $$RepositoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ecosystem => $composableBuilder(
    column: $table.ecosystem,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSync => $composableBuilder(
    column: $table.lastSync,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RepositoriesTableOrderingComposer
    extends Composer<_$AeroDatabase, $RepositoriesTable> {
  $$RepositoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ecosystem => $composableBuilder(
    column: $table.ecosystem,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSync => $composableBuilder(
    column: $table.lastSync,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RepositoriesTableAnnotationComposer
    extends Composer<_$AeroDatabase, $RepositoriesTable> {
  $$RepositoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ecosystem =>
      $composableBuilder(column: $table.ecosystem, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSync =>
      $composableBuilder(column: $table.lastSync, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);
}

class $$RepositoriesTableTableManager
    extends
        RootTableManager<
          _$AeroDatabase,
          $RepositoriesTable,
          PluginRepoRow,
          $$RepositoriesTableFilterComposer,
          $$RepositoriesTableOrderingComposer,
          $$RepositoriesTableAnnotationComposer,
          $$RepositoriesTableCreateCompanionBuilder,
          $$RepositoriesTableUpdateCompanionBuilder,
          (
            PluginRepoRow,
            BaseReferences<_$AeroDatabase, $RepositoriesTable, PluginRepoRow>,
          ),
          PluginRepoRow,
          PrefetchHooks Function()
        > {
  $$RepositoriesTableTableManager(_$AeroDatabase db, $RepositoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RepositoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RepositoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RepositoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> ecosystem = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<DateTime?> lastSync = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RepositoriesCompanion(
                id: id,
                ecosystem: ecosystem,
                url: url,
                name: name,
                lastSync: lastSync,
                enabled: enabled,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String ecosystem,
                required String url,
                required String name,
                Value<DateTime?> lastSync = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RepositoriesCompanion.insert(
                id: id,
                ecosystem: ecosystem,
                url: url,
                name: name,
                lastSync: lastSync,
                enabled: enabled,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RepositoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AeroDatabase,
      $RepositoriesTable,
      PluginRepoRow,
      $$RepositoriesTableFilterComposer,
      $$RepositoriesTableOrderingComposer,
      $$RepositoriesTableAnnotationComposer,
      $$RepositoriesTableCreateCompanionBuilder,
      $$RepositoriesTableUpdateCompanionBuilder,
      (
        PluginRepoRow,
        BaseReferences<_$AeroDatabase, $RepositoriesTable, PluginRepoRow>,
      ),
      PluginRepoRow,
      PrefetchHooks Function()
    >;
typedef $$InstalledSourcesTableCreateCompanionBuilder =
    InstalledSourcesCompanion Function({
      required String id,
      required String ecosystem,
      Value<String?> repoId,
      required String name,
      required String url,
      Value<String> version,
      Value<String?> description,
      Value<String?> logo,
      Value<bool> enabled,
      Value<int> priority,
      Value<String> configJson,
      Value<String?> sha256,
      Value<bool> adult,
      Value<DateTime?> installedAt,
      Value<int> rowid,
    });
typedef $$InstalledSourcesTableUpdateCompanionBuilder =
    InstalledSourcesCompanion Function({
      Value<String> id,
      Value<String> ecosystem,
      Value<String?> repoId,
      Value<String> name,
      Value<String> url,
      Value<String> version,
      Value<String?> description,
      Value<String?> logo,
      Value<bool> enabled,
      Value<int> priority,
      Value<String> configJson,
      Value<String?> sha256,
      Value<bool> adult,
      Value<DateTime?> installedAt,
      Value<int> rowid,
    });

class $$InstalledSourcesTableFilterComposer
    extends Composer<_$AeroDatabase, $InstalledSourcesTable> {
  $$InstalledSourcesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ecosystem => $composableBuilder(
    column: $table.ecosystem,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get repoId => $composableBuilder(
    column: $table.repoId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get logo => $composableBuilder(
    column: $table.logo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get configJson => $composableBuilder(
    column: $table.configJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get adult => $composableBuilder(
    column: $table.adult,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get installedAt => $composableBuilder(
    column: $table.installedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$InstalledSourcesTableOrderingComposer
    extends Composer<_$AeroDatabase, $InstalledSourcesTable> {
  $$InstalledSourcesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ecosystem => $composableBuilder(
    column: $table.ecosystem,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get repoId => $composableBuilder(
    column: $table.repoId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get logo => $composableBuilder(
    column: $table.logo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get configJson => $composableBuilder(
    column: $table.configJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get adult => $composableBuilder(
    column: $table.adult,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get installedAt => $composableBuilder(
    column: $table.installedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$InstalledSourcesTableAnnotationComposer
    extends Composer<_$AeroDatabase, $InstalledSourcesTable> {
  $$InstalledSourcesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ecosystem =>
      $composableBuilder(column: $table.ecosystem, builder: (column) => column);

  GeneratedColumn<String> get repoId =>
      $composableBuilder(column: $table.repoId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get logo =>
      $composableBuilder(column: $table.logo, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<String> get configJson => $composableBuilder(
    column: $table.configJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sha256 =>
      $composableBuilder(column: $table.sha256, builder: (column) => column);

  GeneratedColumn<bool> get adult =>
      $composableBuilder(column: $table.adult, builder: (column) => column);

  GeneratedColumn<DateTime> get installedAt => $composableBuilder(
    column: $table.installedAt,
    builder: (column) => column,
  );
}

class $$InstalledSourcesTableTableManager
    extends
        RootTableManager<
          _$AeroDatabase,
          $InstalledSourcesTable,
          InstalledSourceRow,
          $$InstalledSourcesTableFilterComposer,
          $$InstalledSourcesTableOrderingComposer,
          $$InstalledSourcesTableAnnotationComposer,
          $$InstalledSourcesTableCreateCompanionBuilder,
          $$InstalledSourcesTableUpdateCompanionBuilder,
          (
            InstalledSourceRow,
            BaseReferences<
              _$AeroDatabase,
              $InstalledSourcesTable,
              InstalledSourceRow
            >,
          ),
          InstalledSourceRow,
          PrefetchHooks Function()
        > {
  $$InstalledSourcesTableTableManager(
    _$AeroDatabase db,
    $InstalledSourcesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InstalledSourcesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InstalledSourcesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$InstalledSourcesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> ecosystem = const Value.absent(),
                Value<String?> repoId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<String> version = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> logo = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<String> configJson = const Value.absent(),
                Value<String?> sha256 = const Value.absent(),
                Value<bool> adult = const Value.absent(),
                Value<DateTime?> installedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InstalledSourcesCompanion(
                id: id,
                ecosystem: ecosystem,
                repoId: repoId,
                name: name,
                url: url,
                version: version,
                description: description,
                logo: logo,
                enabled: enabled,
                priority: priority,
                configJson: configJson,
                sha256: sha256,
                adult: adult,
                installedAt: installedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String ecosystem,
                Value<String?> repoId = const Value.absent(),
                required String name,
                required String url,
                Value<String> version = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> logo = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<String> configJson = const Value.absent(),
                Value<String?> sha256 = const Value.absent(),
                Value<bool> adult = const Value.absent(),
                Value<DateTime?> installedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InstalledSourcesCompanion.insert(
                id: id,
                ecosystem: ecosystem,
                repoId: repoId,
                name: name,
                url: url,
                version: version,
                description: description,
                logo: logo,
                enabled: enabled,
                priority: priority,
                configJson: configJson,
                sha256: sha256,
                adult: adult,
                installedAt: installedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$InstalledSourcesTableProcessedTableManager =
    ProcessedTableManager<
      _$AeroDatabase,
      $InstalledSourcesTable,
      InstalledSourceRow,
      $$InstalledSourcesTableFilterComposer,
      $$InstalledSourcesTableOrderingComposer,
      $$InstalledSourcesTableAnnotationComposer,
      $$InstalledSourcesTableCreateCompanionBuilder,
      $$InstalledSourcesTableUpdateCompanionBuilder,
      (
        InstalledSourceRow,
        BaseReferences<
          _$AeroDatabase,
          $InstalledSourcesTable,
          InstalledSourceRow
        >,
      ),
      InstalledSourceRow,
      PrefetchHooks Function()
    >;
typedef $$MediaCacheTableCreateCompanionBuilder =
    MediaCacheCompanion Function({
      required String key,
      required String json,
      required DateTime expiresAt,
      Value<int> rowid,
    });
typedef $$MediaCacheTableUpdateCompanionBuilder =
    MediaCacheCompanion Function({
      Value<String> key,
      Value<String> json,
      Value<DateTime> expiresAt,
      Value<int> rowid,
    });

class $$MediaCacheTableFilterComposer
    extends Composer<_$AeroDatabase, $MediaCacheTable> {
  $$MediaCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MediaCacheTableOrderingComposer
    extends Composer<_$AeroDatabase, $MediaCacheTable> {
  $$MediaCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MediaCacheTableAnnotationComposer
    extends Composer<_$AeroDatabase, $MediaCacheTable> {
  $$MediaCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);

  GeneratedColumn<DateTime> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);
}

class $$MediaCacheTableTableManager
    extends
        RootTableManager<
          _$AeroDatabase,
          $MediaCacheTable,
          MediaCacheRow,
          $$MediaCacheTableFilterComposer,
          $$MediaCacheTableOrderingComposer,
          $$MediaCacheTableAnnotationComposer,
          $$MediaCacheTableCreateCompanionBuilder,
          $$MediaCacheTableUpdateCompanionBuilder,
          (
            MediaCacheRow,
            BaseReferences<_$AeroDatabase, $MediaCacheTable, MediaCacheRow>,
          ),
          MediaCacheRow,
          PrefetchHooks Function()
        > {
  $$MediaCacheTableTableManager(_$AeroDatabase db, $MediaCacheTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MediaCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MediaCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MediaCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> json = const Value.absent(),
                Value<DateTime> expiresAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MediaCacheCompanion(
                key: key,
                json: json,
                expiresAt: expiresAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String json,
                required DateTime expiresAt,
                Value<int> rowid = const Value.absent(),
              }) => MediaCacheCompanion.insert(
                key: key,
                json: json,
                expiresAt: expiresAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MediaCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AeroDatabase,
      $MediaCacheTable,
      MediaCacheRow,
      $$MediaCacheTableFilterComposer,
      $$MediaCacheTableOrderingComposer,
      $$MediaCacheTableAnnotationComposer,
      $$MediaCacheTableCreateCompanionBuilder,
      $$MediaCacheTableUpdateCompanionBuilder,
      (
        MediaCacheRow,
        BaseReferences<_$AeroDatabase, $MediaCacheTable, MediaCacheRow>,
      ),
      MediaCacheRow,
      PrefetchHooks Function()
    >;
typedef $$WatchHistoryTableCreateCompanionBuilder =
    WatchHistoryCompanion Function({
      required String mediaId,
      Value<String> profileId,
      Value<int?> season,
      Value<int?> episode,
      Value<int> positionMs,
      Value<int> durationMs,
      required DateTime updatedAt,
      Value<String> metaJson,
      Value<int> rowid,
    });
typedef $$WatchHistoryTableUpdateCompanionBuilder =
    WatchHistoryCompanion Function({
      Value<String> mediaId,
      Value<String> profileId,
      Value<int?> season,
      Value<int?> episode,
      Value<int> positionMs,
      Value<int> durationMs,
      Value<DateTime> updatedAt,
      Value<String> metaJson,
      Value<int> rowid,
    });

class $$WatchHistoryTableFilterComposer
    extends Composer<_$AeroDatabase, $WatchHistoryTable> {
  $$WatchHistoryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get mediaId => $composableBuilder(
    column: $table.mediaId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get season => $composableBuilder(
    column: $table.season,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get episode => $composableBuilder(
    column: $table.episode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metaJson => $composableBuilder(
    column: $table.metaJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WatchHistoryTableOrderingComposer
    extends Composer<_$AeroDatabase, $WatchHistoryTable> {
  $$WatchHistoryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get mediaId => $composableBuilder(
    column: $table.mediaId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get season => $composableBuilder(
    column: $table.season,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get episode => $composableBuilder(
    column: $table.episode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metaJson => $composableBuilder(
    column: $table.metaJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WatchHistoryTableAnnotationComposer
    extends Composer<_$AeroDatabase, $WatchHistoryTable> {
  $$WatchHistoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get mediaId =>
      $composableBuilder(column: $table.mediaId, builder: (column) => column);

  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<int> get season =>
      $composableBuilder(column: $table.season, builder: (column) => column);

  GeneratedColumn<int> get episode =>
      $composableBuilder(column: $table.episode, builder: (column) => column);

  GeneratedColumn<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get metaJson =>
      $composableBuilder(column: $table.metaJson, builder: (column) => column);
}

class $$WatchHistoryTableTableManager
    extends
        RootTableManager<
          _$AeroDatabase,
          $WatchHistoryTable,
          WatchHistoryRow,
          $$WatchHistoryTableFilterComposer,
          $$WatchHistoryTableOrderingComposer,
          $$WatchHistoryTableAnnotationComposer,
          $$WatchHistoryTableCreateCompanionBuilder,
          $$WatchHistoryTableUpdateCompanionBuilder,
          (
            WatchHistoryRow,
            BaseReferences<_$AeroDatabase, $WatchHistoryTable, WatchHistoryRow>,
          ),
          WatchHistoryRow,
          PrefetchHooks Function()
        > {
  $$WatchHistoryTableTableManager(_$AeroDatabase db, $WatchHistoryTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WatchHistoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WatchHistoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WatchHistoryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> mediaId = const Value.absent(),
                Value<String> profileId = const Value.absent(),
                Value<int?> season = const Value.absent(),
                Value<int?> episode = const Value.absent(),
                Value<int> positionMs = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String> metaJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WatchHistoryCompanion(
                mediaId: mediaId,
                profileId: profileId,
                season: season,
                episode: episode,
                positionMs: positionMs,
                durationMs: durationMs,
                updatedAt: updatedAt,
                metaJson: metaJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String mediaId,
                Value<String> profileId = const Value.absent(),
                Value<int?> season = const Value.absent(),
                Value<int?> episode = const Value.absent(),
                Value<int> positionMs = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                required DateTime updatedAt,
                Value<String> metaJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WatchHistoryCompanion.insert(
                mediaId: mediaId,
                profileId: profileId,
                season: season,
                episode: episode,
                positionMs: positionMs,
                durationMs: durationMs,
                updatedAt: updatedAt,
                metaJson: metaJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WatchHistoryTableProcessedTableManager =
    ProcessedTableManager<
      _$AeroDatabase,
      $WatchHistoryTable,
      WatchHistoryRow,
      $$WatchHistoryTableFilterComposer,
      $$WatchHistoryTableOrderingComposer,
      $$WatchHistoryTableAnnotationComposer,
      $$WatchHistoryTableCreateCompanionBuilder,
      $$WatchHistoryTableUpdateCompanionBuilder,
      (
        WatchHistoryRow,
        BaseReferences<_$AeroDatabase, $WatchHistoryTable, WatchHistoryRow>,
      ),
      WatchHistoryRow,
      PrefetchHooks Function()
    >;
typedef $$LibraryEntriesTableCreateCompanionBuilder =
    LibraryEntriesCompanion Function({
      required String mediaId,
      Value<String> profileId,
      required String listName,
      Value<String> metaJson,
      required DateTime addedAt,
      Value<int> rowid,
    });
typedef $$LibraryEntriesTableUpdateCompanionBuilder =
    LibraryEntriesCompanion Function({
      Value<String> mediaId,
      Value<String> profileId,
      Value<String> listName,
      Value<String> metaJson,
      Value<DateTime> addedAt,
      Value<int> rowid,
    });

class $$LibraryEntriesTableFilterComposer
    extends Composer<_$AeroDatabase, $LibraryEntriesTable> {
  $$LibraryEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get mediaId => $composableBuilder(
    column: $table.mediaId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get listName => $composableBuilder(
    column: $table.listName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metaJson => $composableBuilder(
    column: $table.metaJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LibraryEntriesTableOrderingComposer
    extends Composer<_$AeroDatabase, $LibraryEntriesTable> {
  $$LibraryEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get mediaId => $composableBuilder(
    column: $table.mediaId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get listName => $composableBuilder(
    column: $table.listName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metaJson => $composableBuilder(
    column: $table.metaJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LibraryEntriesTableAnnotationComposer
    extends Composer<_$AeroDatabase, $LibraryEntriesTable> {
  $$LibraryEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get mediaId =>
      $composableBuilder(column: $table.mediaId, builder: (column) => column);

  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<String> get listName =>
      $composableBuilder(column: $table.listName, builder: (column) => column);

  GeneratedColumn<String> get metaJson =>
      $composableBuilder(column: $table.metaJson, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);
}

class $$LibraryEntriesTableTableManager
    extends
        RootTableManager<
          _$AeroDatabase,
          $LibraryEntriesTable,
          LibraryEntryRow,
          $$LibraryEntriesTableFilterComposer,
          $$LibraryEntriesTableOrderingComposer,
          $$LibraryEntriesTableAnnotationComposer,
          $$LibraryEntriesTableCreateCompanionBuilder,
          $$LibraryEntriesTableUpdateCompanionBuilder,
          (
            LibraryEntryRow,
            BaseReferences<
              _$AeroDatabase,
              $LibraryEntriesTable,
              LibraryEntryRow
            >,
          ),
          LibraryEntryRow,
          PrefetchHooks Function()
        > {
  $$LibraryEntriesTableTableManager(
    _$AeroDatabase db,
    $LibraryEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LibraryEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LibraryEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LibraryEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> mediaId = const Value.absent(),
                Value<String> profileId = const Value.absent(),
                Value<String> listName = const Value.absent(),
                Value<String> metaJson = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LibraryEntriesCompanion(
                mediaId: mediaId,
                profileId: profileId,
                listName: listName,
                metaJson: metaJson,
                addedAt: addedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String mediaId,
                Value<String> profileId = const Value.absent(),
                required String listName,
                Value<String> metaJson = const Value.absent(),
                required DateTime addedAt,
                Value<int> rowid = const Value.absent(),
              }) => LibraryEntriesCompanion.insert(
                mediaId: mediaId,
                profileId: profileId,
                listName: listName,
                metaJson: metaJson,
                addedAt: addedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LibraryEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AeroDatabase,
      $LibraryEntriesTable,
      LibraryEntryRow,
      $$LibraryEntriesTableFilterComposer,
      $$LibraryEntriesTableOrderingComposer,
      $$LibraryEntriesTableAnnotationComposer,
      $$LibraryEntriesTableCreateCompanionBuilder,
      $$LibraryEntriesTableUpdateCompanionBuilder,
      (
        LibraryEntryRow,
        BaseReferences<_$AeroDatabase, $LibraryEntriesTable, LibraryEntryRow>,
      ),
      LibraryEntryRow,
      PrefetchHooks Function()
    >;
typedef $$ProfilesTableCreateCompanionBuilder =
    ProfilesCompanion Function({
      required String id,
      required String name,
      Value<String?> avatar,
      Value<String?> pinHash,
      Value<bool> isKids,
      Value<int> rowid,
    });
typedef $$ProfilesTableUpdateCompanionBuilder =
    ProfilesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> avatar,
      Value<String?> pinHash,
      Value<bool> isKids,
      Value<int> rowid,
    });

class $$ProfilesTableFilterComposer
    extends Composer<_$AeroDatabase, $ProfilesTable> {
  $$ProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get avatar => $composableBuilder(
    column: $table.avatar,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pinHash => $composableBuilder(
    column: $table.pinHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isKids => $composableBuilder(
    column: $table.isKids,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProfilesTableOrderingComposer
    extends Composer<_$AeroDatabase, $ProfilesTable> {
  $$ProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get avatar => $composableBuilder(
    column: $table.avatar,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pinHash => $composableBuilder(
    column: $table.pinHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isKids => $composableBuilder(
    column: $table.isKids,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProfilesTableAnnotationComposer
    extends Composer<_$AeroDatabase, $ProfilesTable> {
  $$ProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get avatar =>
      $composableBuilder(column: $table.avatar, builder: (column) => column);

  GeneratedColumn<String> get pinHash =>
      $composableBuilder(column: $table.pinHash, builder: (column) => column);

  GeneratedColumn<bool> get isKids =>
      $composableBuilder(column: $table.isKids, builder: (column) => column);
}

class $$ProfilesTableTableManager
    extends
        RootTableManager<
          _$AeroDatabase,
          $ProfilesTable,
          ProfileRow,
          $$ProfilesTableFilterComposer,
          $$ProfilesTableOrderingComposer,
          $$ProfilesTableAnnotationComposer,
          $$ProfilesTableCreateCompanionBuilder,
          $$ProfilesTableUpdateCompanionBuilder,
          (
            ProfileRow,
            BaseReferences<_$AeroDatabase, $ProfilesTable, ProfileRow>,
          ),
          ProfileRow,
          PrefetchHooks Function()
        > {
  $$ProfilesTableTableManager(_$AeroDatabase db, $ProfilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> avatar = const Value.absent(),
                Value<String?> pinHash = const Value.absent(),
                Value<bool> isKids = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProfilesCompanion(
                id: id,
                name: name,
                avatar: avatar,
                pinHash: pinHash,
                isKids: isKids,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> avatar = const Value.absent(),
                Value<String?> pinHash = const Value.absent(),
                Value<bool> isKids = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProfilesCompanion.insert(
                id: id,
                name: name,
                avatar: avatar,
                pinHash: pinHash,
                isKids: isKids,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AeroDatabase,
      $ProfilesTable,
      ProfileRow,
      $$ProfilesTableFilterComposer,
      $$ProfilesTableOrderingComposer,
      $$ProfilesTableAnnotationComposer,
      $$ProfilesTableCreateCompanionBuilder,
      $$ProfilesTableUpdateCompanionBuilder,
      (ProfileRow, BaseReferences<_$AeroDatabase, $ProfilesTable, ProfileRow>),
      ProfileRow,
      PrefetchHooks Function()
    >;
typedef $$ProviderHealthTableTableCreateCompanionBuilder =
    ProviderHealthTableCompanion Function({
      required String sourceKey,
      Value<int> successCount,
      Value<int> failCount,
      Value<double> avgLatencyMs,
      Value<DateTime?> lastChecked,
      Value<String?> lastError,
      Value<int> rowid,
    });
typedef $$ProviderHealthTableTableUpdateCompanionBuilder =
    ProviderHealthTableCompanion Function({
      Value<String> sourceKey,
      Value<int> successCount,
      Value<int> failCount,
      Value<double> avgLatencyMs,
      Value<DateTime?> lastChecked,
      Value<String?> lastError,
      Value<int> rowid,
    });

class $$ProviderHealthTableTableFilterComposer
    extends Composer<_$AeroDatabase, $ProviderHealthTableTable> {
  $$ProviderHealthTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get sourceKey => $composableBuilder(
    column: $table.sourceKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get successCount => $composableBuilder(
    column: $table.successCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get failCount => $composableBuilder(
    column: $table.failCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get avgLatencyMs => $composableBuilder(
    column: $table.avgLatencyMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastChecked => $composableBuilder(
    column: $table.lastChecked,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProviderHealthTableTableOrderingComposer
    extends Composer<_$AeroDatabase, $ProviderHealthTableTable> {
  $$ProviderHealthTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get sourceKey => $composableBuilder(
    column: $table.sourceKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get successCount => $composableBuilder(
    column: $table.successCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get failCount => $composableBuilder(
    column: $table.failCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get avgLatencyMs => $composableBuilder(
    column: $table.avgLatencyMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastChecked => $composableBuilder(
    column: $table.lastChecked,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProviderHealthTableTableAnnotationComposer
    extends Composer<_$AeroDatabase, $ProviderHealthTableTable> {
  $$ProviderHealthTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sourceKey =>
      $composableBuilder(column: $table.sourceKey, builder: (column) => column);

  GeneratedColumn<int> get successCount => $composableBuilder(
    column: $table.successCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get failCount =>
      $composableBuilder(column: $table.failCount, builder: (column) => column);

  GeneratedColumn<double> get avgLatencyMs => $composableBuilder(
    column: $table.avgLatencyMs,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastChecked => $composableBuilder(
    column: $table.lastChecked,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);
}

class $$ProviderHealthTableTableTableManager
    extends
        RootTableManager<
          _$AeroDatabase,
          $ProviderHealthTableTable,
          ProviderHealthRow,
          $$ProviderHealthTableTableFilterComposer,
          $$ProviderHealthTableTableOrderingComposer,
          $$ProviderHealthTableTableAnnotationComposer,
          $$ProviderHealthTableTableCreateCompanionBuilder,
          $$ProviderHealthTableTableUpdateCompanionBuilder,
          (
            ProviderHealthRow,
            BaseReferences<
              _$AeroDatabase,
              $ProviderHealthTableTable,
              ProviderHealthRow
            >,
          ),
          ProviderHealthRow,
          PrefetchHooks Function()
        > {
  $$ProviderHealthTableTableTableManager(
    _$AeroDatabase db,
    $ProviderHealthTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProviderHealthTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProviderHealthTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ProviderHealthTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> sourceKey = const Value.absent(),
                Value<int> successCount = const Value.absent(),
                Value<int> failCount = const Value.absent(),
                Value<double> avgLatencyMs = const Value.absent(),
                Value<DateTime?> lastChecked = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProviderHealthTableCompanion(
                sourceKey: sourceKey,
                successCount: successCount,
                failCount: failCount,
                avgLatencyMs: avgLatencyMs,
                lastChecked: lastChecked,
                lastError: lastError,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sourceKey,
                Value<int> successCount = const Value.absent(),
                Value<int> failCount = const Value.absent(),
                Value<double> avgLatencyMs = const Value.absent(),
                Value<DateTime?> lastChecked = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProviderHealthTableCompanion.insert(
                sourceKey: sourceKey,
                successCount: successCount,
                failCount: failCount,
                avgLatencyMs: avgLatencyMs,
                lastChecked: lastChecked,
                lastError: lastError,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProviderHealthTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AeroDatabase,
      $ProviderHealthTableTable,
      ProviderHealthRow,
      $$ProviderHealthTableTableFilterComposer,
      $$ProviderHealthTableTableOrderingComposer,
      $$ProviderHealthTableTableAnnotationComposer,
      $$ProviderHealthTableTableCreateCompanionBuilder,
      $$ProviderHealthTableTableUpdateCompanionBuilder,
      (
        ProviderHealthRow,
        BaseReferences<
          _$AeroDatabase,
          $ProviderHealthTableTable,
          ProviderHealthRow
        >,
      ),
      ProviderHealthRow,
      PrefetchHooks Function()
    >;
typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      required String key,
      required String valueJson,
      Value<int> rowid,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<String> key,
      Value<String> valueJson,
      Value<int> rowid,
    });

class $$AppSettingsTableFilterComposer
    extends Composer<_$AeroDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get valueJson => $composableBuilder(
    column: $table.valueJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AeroDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get valueJson => $composableBuilder(
    column: $table.valueJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AeroDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get valueJson =>
      $composableBuilder(column: $table.valueJson, builder: (column) => column);
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$AeroDatabase,
          $AppSettingsTable,
          AppSettingRow,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (
            AppSettingRow,
            BaseReferences<_$AeroDatabase, $AppSettingsTable, AppSettingRow>,
          ),
          AppSettingRow,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$AeroDatabase db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> valueJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion(
                key: key,
                valueJson: valueJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String valueJson,
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                key: key,
                valueJson: valueJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AeroDatabase,
      $AppSettingsTable,
      AppSettingRow,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        AppSettingRow,
        BaseReferences<_$AeroDatabase, $AppSettingsTable, AppSettingRow>,
      ),
      AppSettingRow,
      PrefetchHooks Function()
    >;
typedef $$IdMappingsTableCreateCompanionBuilder =
    IdMappingsCompanion Function({
      required String key,
      required String json,
      required DateTime fetchedAt,
      Value<int> rowid,
    });
typedef $$IdMappingsTableUpdateCompanionBuilder =
    IdMappingsCompanion Function({
      Value<String> key,
      Value<String> json,
      Value<DateTime> fetchedAt,
      Value<int> rowid,
    });

class $$IdMappingsTableFilterComposer
    extends Composer<_$AeroDatabase, $IdMappingsTable> {
  $$IdMappingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$IdMappingsTableOrderingComposer
    extends Composer<_$AeroDatabase, $IdMappingsTable> {
  $$IdMappingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$IdMappingsTableAnnotationComposer
    extends Composer<_$AeroDatabase, $IdMappingsTable> {
  $$IdMappingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);

  GeneratedColumn<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);
}

class $$IdMappingsTableTableManager
    extends
        RootTableManager<
          _$AeroDatabase,
          $IdMappingsTable,
          IdMappingRow,
          $$IdMappingsTableFilterComposer,
          $$IdMappingsTableOrderingComposer,
          $$IdMappingsTableAnnotationComposer,
          $$IdMappingsTableCreateCompanionBuilder,
          $$IdMappingsTableUpdateCompanionBuilder,
          (
            IdMappingRow,
            BaseReferences<_$AeroDatabase, $IdMappingsTable, IdMappingRow>,
          ),
          IdMappingRow,
          PrefetchHooks Function()
        > {
  $$IdMappingsTableTableManager(_$AeroDatabase db, $IdMappingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$IdMappingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$IdMappingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$IdMappingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> json = const Value.absent(),
                Value<DateTime> fetchedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => IdMappingsCompanion(
                key: key,
                json: json,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String json,
                required DateTime fetchedAt,
                Value<int> rowid = const Value.absent(),
              }) => IdMappingsCompanion.insert(
                key: key,
                json: json,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$IdMappingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AeroDatabase,
      $IdMappingsTable,
      IdMappingRow,
      $$IdMappingsTableFilterComposer,
      $$IdMappingsTableOrderingComposer,
      $$IdMappingsTableAnnotationComposer,
      $$IdMappingsTableCreateCompanionBuilder,
      $$IdMappingsTableUpdateCompanionBuilder,
      (
        IdMappingRow,
        BaseReferences<_$AeroDatabase, $IdMappingsTable, IdMappingRow>,
      ),
      IdMappingRow,
      PrefetchHooks Function()
    >;

class $AeroDatabaseManager {
  final _$AeroDatabase _db;
  $AeroDatabaseManager(this._db);
  $$RepositoriesTableTableManager get repositories =>
      $$RepositoriesTableTableManager(_db, _db.repositories);
  $$InstalledSourcesTableTableManager get installedSources =>
      $$InstalledSourcesTableTableManager(_db, _db.installedSources);
  $$MediaCacheTableTableManager get mediaCache =>
      $$MediaCacheTableTableManager(_db, _db.mediaCache);
  $$WatchHistoryTableTableManager get watchHistory =>
      $$WatchHistoryTableTableManager(_db, _db.watchHistory);
  $$LibraryEntriesTableTableManager get libraryEntries =>
      $$LibraryEntriesTableTableManager(_db, _db.libraryEntries);
  $$ProfilesTableTableManager get profiles =>
      $$ProfilesTableTableManager(_db, _db.profiles);
  $$ProviderHealthTableTableTableManager get providerHealthTable =>
      $$ProviderHealthTableTableTableManager(_db, _db.providerHealthTable);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
  $$IdMappingsTableTableManager get idMappings =>
      $$IdMappingsTableTableManager(_db, _db.idMappings);
}
