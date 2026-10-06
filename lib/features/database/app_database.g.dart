// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ShopsTable extends Shops with TableInfo<$ShopsTable, Shop> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ShopsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _latitudeMeta = const VerificationMeta(
    'latitude',
  );
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
    'latitude',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _longitudeMeta = const VerificationMeta(
    'longitude',
  );
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
    'longitude',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _osmIdMeta = const VerificationMeta('osmId');
  @override
  late final GeneratedColumn<String> osmId = GeneratedColumn<String>(
    'osm_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isFamousMeta = const VerificationMeta(
    'isFamous',
  );
  @override
  late final GeneratedColumn<bool> isFamous = GeneratedColumn<bool>(
    'is_famous',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_famous" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _strategyMemoMeta = const VerificationMeta(
    'strategyMemo',
  );
  @override
  late final GeneratedColumn<String> strategyMemo = GeneratedColumn<String>(
    'strategy_memo',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  late final GeneratedColumnWithTypeConverter<ShopSource?, String> dataSource =
      GeneratedColumn<String>(
        'data_source',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<ShopSource?>($ShopsTable.$converterdataSourcen);
  static const VerificationMeta _areaMeta = const VerificationMeta('area');
  @override
  late final GeneratedColumn<String> area = GeneratedColumn<String>(
    'area',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    latitude,
    longitude,
    osmId,
    isFamous,
    strategyMemo,
    dataSource,
    area,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shops';
  @override
  VerificationContext validateIntegrity(
    Insertable<Shop> instance, {
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
    if (data.containsKey('latitude')) {
      context.handle(
        _latitudeMeta,
        latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta),
      );
    }
    if (data.containsKey('longitude')) {
      context.handle(
        _longitudeMeta,
        longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta),
      );
    }
    if (data.containsKey('osm_id')) {
      context.handle(
        _osmIdMeta,
        osmId.isAcceptableOrUnknown(data['osm_id']!, _osmIdMeta),
      );
    }
    if (data.containsKey('is_famous')) {
      context.handle(
        _isFamousMeta,
        isFamous.isAcceptableOrUnknown(data['is_famous']!, _isFamousMeta),
      );
    }
    if (data.containsKey('strategy_memo')) {
      context.handle(
        _strategyMemoMeta,
        strategyMemo.isAcceptableOrUnknown(
          data['strategy_memo']!,
          _strategyMemoMeta,
        ),
      );
    }
    if (data.containsKey('area')) {
      context.handle(
        _areaMeta,
        area.isAcceptableOrUnknown(data['area']!, _areaMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Shop map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Shop(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      latitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}latitude'],
      ),
      longitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}longitude'],
      ),
      osmId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}osm_id'],
      ),
      isFamous: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_famous'],
      )!,
      strategyMemo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}strategy_memo'],
      )!,
      dataSource: $ShopsTable.$converterdataSourcen.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}data_source'],
        ),
      ),
      area: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}area'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ShopsTable createAlias(String alias) {
    return $ShopsTable(attachedDatabase, alias);
  }

  static TypeConverter<ShopSource, String> $converterdataSource =
      const ShopSourceConverter();
  static TypeConverter<ShopSource?, String?> $converterdataSourcen =
      NullAwareTypeConverter.wrap($converterdataSource);
}

class ShopsCompanion extends UpdateCompanion<Shop> {
  final Value<String> id;
  final Value<String> name;
  final Value<double?> latitude;
  final Value<double?> longitude;
  final Value<String?> osmId;
  final Value<bool> isFamous;
  final Value<String> strategyMemo;
  final Value<ShopSource?> dataSource;
  final Value<String?> area;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ShopsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.osmId = const Value.absent(),
    this.isFamous = const Value.absent(),
    this.strategyMemo = const Value.absent(),
    this.dataSource = const Value.absent(),
    this.area = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ShopsCompanion.insert({
    required String id,
    required String name,
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.osmId = const Value.absent(),
    this.isFamous = const Value.absent(),
    this.strategyMemo = const Value.absent(),
    this.dataSource = const Value.absent(),
    this.area = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<Shop> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<String>? osmId,
    Expression<bool>? isFamous,
    Expression<String>? strategyMemo,
    Expression<String>? dataSource,
    Expression<String>? area,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (osmId != null) 'osm_id': osmId,
      if (isFamous != null) 'is_famous': isFamous,
      if (strategyMemo != null) 'strategy_memo': strategyMemo,
      if (dataSource != null) 'data_source': dataSource,
      if (area != null) 'area': area,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ShopsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<double?>? latitude,
    Value<double?>? longitude,
    Value<String?>? osmId,
    Value<bool>? isFamous,
    Value<String>? strategyMemo,
    Value<ShopSource?>? dataSource,
    Value<String?>? area,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ShopsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      osmId: osmId ?? this.osmId,
      isFamous: isFamous ?? this.isFamous,
      strategyMemo: strategyMemo ?? this.strategyMemo,
      dataSource: dataSource ?? this.dataSource,
      area: area ?? this.area,
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
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (osmId.present) {
      map['osm_id'] = Variable<String>(osmId.value);
    }
    if (isFamous.present) {
      map['is_famous'] = Variable<bool>(isFamous.value);
    }
    if (strategyMemo.present) {
      map['strategy_memo'] = Variable<String>(strategyMemo.value);
    }
    if (dataSource.present) {
      map['data_source'] = Variable<String>(
        $ShopsTable.$converterdataSourcen.toSql(dataSource.value),
      );
    }
    if (area.present) {
      map['area'] = Variable<String>(area.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ShopsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('osmId: $osmId, ')
          ..write('isFamous: $isFamous, ')
          ..write('strategyMemo: $strategyMemo, ')
          ..write('dataSource: $dataSource, ')
          ..write('area: $area, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $VisitsTable extends Visits with TableInfo<$VisitsTable, Visit> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VisitsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _shopIdMeta = const VerificationMeta('shopId');
  @override
  late final GeneratedColumn<String> shopId = GeneratedColumn<String>(
    'shop_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES shops (id)',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<VisitResult, String> result =
      GeneratedColumn<String>(
        'result',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<VisitResult>($VisitsTable.$converterresult);
  static const VerificationMeta _photoPathMeta = const VerificationMeta(
    'photoPath',
  );
  @override
  late final GeneratedColumn<String> photoPath = GeneratedColumn<String>(
    'photo_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _checkedInAtMeta = const VerificationMeta(
    'checkedInAt',
  );
  @override
  late final GeneratedColumn<DateTime> checkedInAt = GeneratedColumn<DateTime>(
    'checked_in_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _eatenAtMeta = const VerificationMeta(
    'eatenAt',
  );
  @override
  late final GeneratedColumn<DateTime> eatenAt = GeneratedColumn<DateTime>(
    'eaten_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<RamenStyle?, String> style =
      GeneratedColumn<String>(
        'style',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<RamenStyle?>($VisitsTable.$converterstylen);
  static const VerificationMeta _ratingMeta = const VerificationMeta('rating');
  @override
  late final GeneratedColumn<int> rating = GeneratedColumn<int>(
    'rating',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isLimitedMeta = const VerificationMeta(
    'isLimited',
  );
  @override
  late final GeneratedColumn<bool> isLimited = GeneratedColumn<bool>(
    'is_limited',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_limited" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _memoMeta = const VerificationMeta('memo');
  @override
  late final GeneratedColumn<String> memo = GeneratedColumn<String>(
    'memo',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    shopId,
    result,
    photoPath,
    checkedInAt,
    eatenAt,
    style,
    rating,
    isLimited,
    memo,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'visits';
  @override
  VerificationContext validateIntegrity(
    Insertable<Visit> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('shop_id')) {
      context.handle(
        _shopIdMeta,
        shopId.isAcceptableOrUnknown(data['shop_id']!, _shopIdMeta),
      );
    } else if (isInserting) {
      context.missing(_shopIdMeta);
    }
    if (data.containsKey('photo_path')) {
      context.handle(
        _photoPathMeta,
        photoPath.isAcceptableOrUnknown(data['photo_path']!, _photoPathMeta),
      );
    }
    if (data.containsKey('checked_in_at')) {
      context.handle(
        _checkedInAtMeta,
        checkedInAt.isAcceptableOrUnknown(
          data['checked_in_at']!,
          _checkedInAtMeta,
        ),
      );
    }
    if (data.containsKey('eaten_at')) {
      context.handle(
        _eatenAtMeta,
        eatenAt.isAcceptableOrUnknown(data['eaten_at']!, _eatenAtMeta),
      );
    } else if (isInserting) {
      context.missing(_eatenAtMeta);
    }
    if (data.containsKey('rating')) {
      context.handle(
        _ratingMeta,
        rating.isAcceptableOrUnknown(data['rating']!, _ratingMeta),
      );
    }
    if (data.containsKey('is_limited')) {
      context.handle(
        _isLimitedMeta,
        isLimited.isAcceptableOrUnknown(data['is_limited']!, _isLimitedMeta),
      );
    }
    if (data.containsKey('memo')) {
      context.handle(
        _memoMeta,
        memo.isAcceptableOrUnknown(data['memo']!, _memoMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Visit map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Visit(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      shopId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}shop_id'],
      )!,
      result: $VisitsTable.$converterresult.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}result'],
        )!,
      ),
      photoPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}photo_path'],
      ),
      checkedInAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}checked_in_at'],
      ),
      eatenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}eaten_at'],
      )!,
      style: $VisitsTable.$converterstylen.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}style'],
        ),
      ),
      rating: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rating'],
      ),
      isLimited: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_limited'],
      )!,
      memo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}memo'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $VisitsTable createAlias(String alias) {
    return $VisitsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<VisitResult, String, String> $converterresult =
      const EnumNameConverter<VisitResult>(VisitResult.values);
  static JsonTypeConverter2<RamenStyle, String, String> $converterstyle =
      const EnumNameConverter<RamenStyle>(RamenStyle.values);
  static JsonTypeConverter2<RamenStyle?, String?, String?> $converterstylen =
      JsonTypeConverter2.asNullable($converterstyle);
}

class VisitsCompanion extends UpdateCompanion<Visit> {
  final Value<String> id;
  final Value<String> shopId;
  final Value<VisitResult> result;
  final Value<String?> photoPath;
  final Value<DateTime?> checkedInAt;
  final Value<DateTime> eatenAt;
  final Value<RamenStyle?> style;
  final Value<int?> rating;
  final Value<bool> isLimited;
  final Value<String> memo;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const VisitsCompanion({
    this.id = const Value.absent(),
    this.shopId = const Value.absent(),
    this.result = const Value.absent(),
    this.photoPath = const Value.absent(),
    this.checkedInAt = const Value.absent(),
    this.eatenAt = const Value.absent(),
    this.style = const Value.absent(),
    this.rating = const Value.absent(),
    this.isLimited = const Value.absent(),
    this.memo = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VisitsCompanion.insert({
    required String id,
    required String shopId,
    required VisitResult result,
    this.photoPath = const Value.absent(),
    this.checkedInAt = const Value.absent(),
    required DateTime eatenAt,
    this.style = const Value.absent(),
    this.rating = const Value.absent(),
    this.isLimited = const Value.absent(),
    this.memo = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       shopId = Value(shopId),
       result = Value(result),
       eatenAt = Value(eatenAt),
       createdAt = Value(createdAt);
  static Insertable<Visit> custom({
    Expression<String>? id,
    Expression<String>? shopId,
    Expression<String>? result,
    Expression<String>? photoPath,
    Expression<DateTime>? checkedInAt,
    Expression<DateTime>? eatenAt,
    Expression<String>? style,
    Expression<int>? rating,
    Expression<bool>? isLimited,
    Expression<String>? memo,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (shopId != null) 'shop_id': shopId,
      if (result != null) 'result': result,
      if (photoPath != null) 'photo_path': photoPath,
      if (checkedInAt != null) 'checked_in_at': checkedInAt,
      if (eatenAt != null) 'eaten_at': eatenAt,
      if (style != null) 'style': style,
      if (rating != null) 'rating': rating,
      if (isLimited != null) 'is_limited': isLimited,
      if (memo != null) 'memo': memo,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VisitsCompanion copyWith({
    Value<String>? id,
    Value<String>? shopId,
    Value<VisitResult>? result,
    Value<String?>? photoPath,
    Value<DateTime?>? checkedInAt,
    Value<DateTime>? eatenAt,
    Value<RamenStyle?>? style,
    Value<int?>? rating,
    Value<bool>? isLimited,
    Value<String>? memo,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return VisitsCompanion(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      result: result ?? this.result,
      photoPath: photoPath ?? this.photoPath,
      checkedInAt: checkedInAt ?? this.checkedInAt,
      eatenAt: eatenAt ?? this.eatenAt,
      style: style ?? this.style,
      rating: rating ?? this.rating,
      isLimited: isLimited ?? this.isLimited,
      memo: memo ?? this.memo,
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
    if (shopId.present) {
      map['shop_id'] = Variable<String>(shopId.value);
    }
    if (result.present) {
      map['result'] = Variable<String>(
        $VisitsTable.$converterresult.toSql(result.value),
      );
    }
    if (photoPath.present) {
      map['photo_path'] = Variable<String>(photoPath.value);
    }
    if (checkedInAt.present) {
      map['checked_in_at'] = Variable<DateTime>(checkedInAt.value);
    }
    if (eatenAt.present) {
      map['eaten_at'] = Variable<DateTime>(eatenAt.value);
    }
    if (style.present) {
      map['style'] = Variable<String>(
        $VisitsTable.$converterstylen.toSql(style.value),
      );
    }
    if (rating.present) {
      map['rating'] = Variable<int>(rating.value);
    }
    if (isLimited.present) {
      map['is_limited'] = Variable<bool>(isLimited.value);
    }
    if (memo.present) {
      map['memo'] = Variable<String>(memo.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VisitsCompanion(')
          ..write('id: $id, ')
          ..write('shopId: $shopId, ')
          ..write('result: $result, ')
          ..write('photoPath: $photoPath, ')
          ..write('checkedInAt: $checkedInAt, ')
          ..write('eatenAt: $eatenAt, ')
          ..write('style: $style, ')
          ..write('rating: $rating, ')
          ..write('isLimited: $isLimited, ')
          ..write('memo: $memo, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ActiveCheckinsTable extends ActiveCheckins
    with TableInfo<$ActiveCheckinsTable, ActiveCheckin> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ActiveCheckinsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _shopIdMeta = const VerificationMeta('shopId');
  @override
  late final GeneratedColumn<String> shopId = GeneratedColumn<String>(
    'shop_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _osmIdMeta = const VerificationMeta('osmId');
  @override
  late final GeneratedColumn<String> osmId = GeneratedColumn<String>(
    'osm_id',
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
  static const VerificationMeta _latitudeMeta = const VerificationMeta(
    'latitude',
  );
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
    'latitude',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _longitudeMeta = const VerificationMeta(
    'longitude',
  );
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
    'longitude',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<ShopSource?, String> dataSource =
      GeneratedColumn<String>(
        'data_source',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<ShopSource?>($ActiveCheckinsTable.$converterdataSourcen);
  static const VerificationMeta _checkedInAtMeta = const VerificationMeta(
    'checkedInAt',
  );
  @override
  late final GeneratedColumn<DateTime> checkedInAt = GeneratedColumn<DateTime>(
    'checked_in_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    shopId,
    osmId,
    name,
    latitude,
    longitude,
    dataSource,
    checkedInAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'active_checkins';
  @override
  VerificationContext validateIntegrity(
    Insertable<ActiveCheckin> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('shop_id')) {
      context.handle(
        _shopIdMeta,
        shopId.isAcceptableOrUnknown(data['shop_id']!, _shopIdMeta),
      );
    }
    if (data.containsKey('osm_id')) {
      context.handle(
        _osmIdMeta,
        osmId.isAcceptableOrUnknown(data['osm_id']!, _osmIdMeta),
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
    if (data.containsKey('latitude')) {
      context.handle(
        _latitudeMeta,
        latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta),
      );
    }
    if (data.containsKey('longitude')) {
      context.handle(
        _longitudeMeta,
        longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta),
      );
    }
    if (data.containsKey('checked_in_at')) {
      context.handle(
        _checkedInAtMeta,
        checkedInAt.isAcceptableOrUnknown(
          data['checked_in_at']!,
          _checkedInAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_checkedInAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ActiveCheckin map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ActiveCheckin(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      shopId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}shop_id'],
      ),
      osmId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}osm_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      latitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}latitude'],
      ),
      longitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}longitude'],
      ),
      dataSource: $ActiveCheckinsTable.$converterdataSourcen.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}data_source'],
        ),
      ),
      checkedInAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}checked_in_at'],
      )!,
    );
  }

  @override
  $ActiveCheckinsTable createAlias(String alias) {
    return $ActiveCheckinsTable(attachedDatabase, alias);
  }

  static TypeConverter<ShopSource, String> $converterdataSource =
      const ShopSourceConverter();
  static TypeConverter<ShopSource?, String?> $converterdataSourcen =
      NullAwareTypeConverter.wrap($converterdataSource);
}

class ActiveCheckin extends DataClass implements Insertable<ActiveCheckin> {
  final int id;
  final String? shopId;
  final String? osmId;
  final String name;
  final double? latitude;
  final double? longitude;
  final ShopSource? dataSource;
  final DateTime checkedInAt;
  const ActiveCheckin({
    required this.id,
    this.shopId,
    this.osmId,
    required this.name,
    this.latitude,
    this.longitude,
    this.dataSource,
    required this.checkedInAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || shopId != null) {
      map['shop_id'] = Variable<String>(shopId);
    }
    if (!nullToAbsent || osmId != null) {
      map['osm_id'] = Variable<String>(osmId);
    }
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || latitude != null) {
      map['latitude'] = Variable<double>(latitude);
    }
    if (!nullToAbsent || longitude != null) {
      map['longitude'] = Variable<double>(longitude);
    }
    if (!nullToAbsent || dataSource != null) {
      map['data_source'] = Variable<String>(
        $ActiveCheckinsTable.$converterdataSourcen.toSql(dataSource),
      );
    }
    map['checked_in_at'] = Variable<DateTime>(checkedInAt);
    return map;
  }

  ActiveCheckinsCompanion toCompanion(bool nullToAbsent) {
    return ActiveCheckinsCompanion(
      id: Value(id),
      shopId: shopId == null && nullToAbsent
          ? const Value.absent()
          : Value(shopId),
      osmId: osmId == null && nullToAbsent
          ? const Value.absent()
          : Value(osmId),
      name: Value(name),
      latitude: latitude == null && nullToAbsent
          ? const Value.absent()
          : Value(latitude),
      longitude: longitude == null && nullToAbsent
          ? const Value.absent()
          : Value(longitude),
      dataSource: dataSource == null && nullToAbsent
          ? const Value.absent()
          : Value(dataSource),
      checkedInAt: Value(checkedInAt),
    );
  }

  factory ActiveCheckin.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ActiveCheckin(
      id: serializer.fromJson<int>(json['id']),
      shopId: serializer.fromJson<String?>(json['shopId']),
      osmId: serializer.fromJson<String?>(json['osmId']),
      name: serializer.fromJson<String>(json['name']),
      latitude: serializer.fromJson<double?>(json['latitude']),
      longitude: serializer.fromJson<double?>(json['longitude']),
      dataSource: serializer.fromJson<ShopSource?>(json['dataSource']),
      checkedInAt: serializer.fromJson<DateTime>(json['checkedInAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'shopId': serializer.toJson<String?>(shopId),
      'osmId': serializer.toJson<String?>(osmId),
      'name': serializer.toJson<String>(name),
      'latitude': serializer.toJson<double?>(latitude),
      'longitude': serializer.toJson<double?>(longitude),
      'dataSource': serializer.toJson<ShopSource?>(dataSource),
      'checkedInAt': serializer.toJson<DateTime>(checkedInAt),
    };
  }

  ActiveCheckin copyWith({
    int? id,
    Value<String?> shopId = const Value.absent(),
    Value<String?> osmId = const Value.absent(),
    String? name,
    Value<double?> latitude = const Value.absent(),
    Value<double?> longitude = const Value.absent(),
    Value<ShopSource?> dataSource = const Value.absent(),
    DateTime? checkedInAt,
  }) => ActiveCheckin(
    id: id ?? this.id,
    shopId: shopId.present ? shopId.value : this.shopId,
    osmId: osmId.present ? osmId.value : this.osmId,
    name: name ?? this.name,
    latitude: latitude.present ? latitude.value : this.latitude,
    longitude: longitude.present ? longitude.value : this.longitude,
    dataSource: dataSource.present ? dataSource.value : this.dataSource,
    checkedInAt: checkedInAt ?? this.checkedInAt,
  );
  ActiveCheckin copyWithCompanion(ActiveCheckinsCompanion data) {
    return ActiveCheckin(
      id: data.id.present ? data.id.value : this.id,
      shopId: data.shopId.present ? data.shopId.value : this.shopId,
      osmId: data.osmId.present ? data.osmId.value : this.osmId,
      name: data.name.present ? data.name.value : this.name,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      dataSource: data.dataSource.present
          ? data.dataSource.value
          : this.dataSource,
      checkedInAt: data.checkedInAt.present
          ? data.checkedInAt.value
          : this.checkedInAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ActiveCheckin(')
          ..write('id: $id, ')
          ..write('shopId: $shopId, ')
          ..write('osmId: $osmId, ')
          ..write('name: $name, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('dataSource: $dataSource, ')
          ..write('checkedInAt: $checkedInAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    shopId,
    osmId,
    name,
    latitude,
    longitude,
    dataSource,
    checkedInAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ActiveCheckin &&
          other.id == this.id &&
          other.shopId == this.shopId &&
          other.osmId == this.osmId &&
          other.name == this.name &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.dataSource == this.dataSource &&
          other.checkedInAt == this.checkedInAt);
}

class ActiveCheckinsCompanion extends UpdateCompanion<ActiveCheckin> {
  final Value<int> id;
  final Value<String?> shopId;
  final Value<String?> osmId;
  final Value<String> name;
  final Value<double?> latitude;
  final Value<double?> longitude;
  final Value<ShopSource?> dataSource;
  final Value<DateTime> checkedInAt;
  const ActiveCheckinsCompanion({
    this.id = const Value.absent(),
    this.shopId = const Value.absent(),
    this.osmId = const Value.absent(),
    this.name = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.dataSource = const Value.absent(),
    this.checkedInAt = const Value.absent(),
  });
  ActiveCheckinsCompanion.insert({
    this.id = const Value.absent(),
    this.shopId = const Value.absent(),
    this.osmId = const Value.absent(),
    required String name,
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.dataSource = const Value.absent(),
    required DateTime checkedInAt,
  }) : name = Value(name),
       checkedInAt = Value(checkedInAt);
  static Insertable<ActiveCheckin> custom({
    Expression<int>? id,
    Expression<String>? shopId,
    Expression<String>? osmId,
    Expression<String>? name,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<String>? dataSource,
    Expression<DateTime>? checkedInAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (shopId != null) 'shop_id': shopId,
      if (osmId != null) 'osm_id': osmId,
      if (name != null) 'name': name,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (dataSource != null) 'data_source': dataSource,
      if (checkedInAt != null) 'checked_in_at': checkedInAt,
    });
  }

  ActiveCheckinsCompanion copyWith({
    Value<int>? id,
    Value<String?>? shopId,
    Value<String?>? osmId,
    Value<String>? name,
    Value<double?>? latitude,
    Value<double?>? longitude,
    Value<ShopSource?>? dataSource,
    Value<DateTime>? checkedInAt,
  }) {
    return ActiveCheckinsCompanion(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      osmId: osmId ?? this.osmId,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      dataSource: dataSource ?? this.dataSource,
      checkedInAt: checkedInAt ?? this.checkedInAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (shopId.present) {
      map['shop_id'] = Variable<String>(shopId.value);
    }
    if (osmId.present) {
      map['osm_id'] = Variable<String>(osmId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (dataSource.present) {
      map['data_source'] = Variable<String>(
        $ActiveCheckinsTable.$converterdataSourcen.toSql(dataSource.value),
      );
    }
    if (checkedInAt.present) {
      map['checked_in_at'] = Variable<DateTime>(checkedInAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ActiveCheckinsCompanion(')
          ..write('id: $id, ')
          ..write('shopId: $shopId, ')
          ..write('osmId: $osmId, ')
          ..write('name: $name, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('dataSource: $dataSource, ')
          ..write('checkedInAt: $checkedInAt')
          ..write(')'))
        .toString();
  }
}

class $WishesTable extends Wishes with TableInfo<$WishesTable, Wish> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WishesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _shopIdMeta = const VerificationMeta('shopId');
  @override
  late final GeneratedColumn<String> shopId = GeneratedColumn<String>(
    'shop_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _osmIdMeta = const VerificationMeta('osmId');
  @override
  late final GeneratedColumn<String> osmId = GeneratedColumn<String>(
    'osm_id',
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
  static const VerificationMeta _latitudeMeta = const VerificationMeta(
    'latitude',
  );
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
    'latitude',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _longitudeMeta = const VerificationMeta(
    'longitude',
  );
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
    'longitude',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<ShopSource?, String> dataSource =
      GeneratedColumn<String>(
        'data_source',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<ShopSource?>($WishesTable.$converterdataSourcen);
  static const VerificationMeta _triggerMeta = const VerificationMeta(
    'trigger',
  );
  @override
  late final GeneratedColumn<String> trigger = GeneratedColumn<String>(
    'trigger',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fulfilledVisitIdMeta = const VerificationMeta(
    'fulfilledVisitId',
  );
  @override
  late final GeneratedColumn<String> fulfilledVisitId = GeneratedColumn<String>(
    'fulfilled_visit_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _linkMeta = const VerificationMeta('link');
  @override
  late final GeneratedColumn<String> link = GeneratedColumn<String>(
    'link',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    shopId,
    osmId,
    name,
    latitude,
    longitude,
    dataSource,
    trigger,
    note,
    createdAt,
    fulfilledVisitId,
    link,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'wishes';
  @override
  VerificationContext validateIntegrity(
    Insertable<Wish> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('shop_id')) {
      context.handle(
        _shopIdMeta,
        shopId.isAcceptableOrUnknown(data['shop_id']!, _shopIdMeta),
      );
    }
    if (data.containsKey('osm_id')) {
      context.handle(
        _osmIdMeta,
        osmId.isAcceptableOrUnknown(data['osm_id']!, _osmIdMeta),
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
    if (data.containsKey('latitude')) {
      context.handle(
        _latitudeMeta,
        latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta),
      );
    }
    if (data.containsKey('longitude')) {
      context.handle(
        _longitudeMeta,
        longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta),
      );
    }
    if (data.containsKey('trigger')) {
      context.handle(
        _triggerMeta,
        trigger.isAcceptableOrUnknown(data['trigger']!, _triggerMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('fulfilled_visit_id')) {
      context.handle(
        _fulfilledVisitIdMeta,
        fulfilledVisitId.isAcceptableOrUnknown(
          data['fulfilled_visit_id']!,
          _fulfilledVisitIdMeta,
        ),
      );
    }
    if (data.containsKey('link')) {
      context.handle(
        _linkMeta,
        link.isAcceptableOrUnknown(data['link']!, _linkMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Wish map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Wish(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      shopId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}shop_id'],
      ),
      osmId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}osm_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      latitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}latitude'],
      ),
      longitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}longitude'],
      ),
      dataSource: $WishesTable.$converterdataSourcen.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}data_source'],
        ),
      ),
      trigger: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}trigger'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      )!,
      link: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}link'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      fulfilledVisitId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fulfilled_visit_id'],
      ),
    );
  }

  @override
  $WishesTable createAlias(String alias) {
    return $WishesTable(attachedDatabase, alias);
  }

  static TypeConverter<ShopSource, String> $converterdataSource =
      const ShopSourceConverter();
  static TypeConverter<ShopSource?, String?> $converterdataSourcen =
      NullAwareTypeConverter.wrap($converterdataSource);
}

class WishesCompanion extends UpdateCompanion<Wish> {
  final Value<String> id;
  final Value<String?> shopId;
  final Value<String?> osmId;
  final Value<String> name;
  final Value<double?> latitude;
  final Value<double?> longitude;
  final Value<ShopSource?> dataSource;
  final Value<String> trigger;
  final Value<String> note;
  final Value<DateTime> createdAt;
  final Value<String?> fulfilledVisitId;
  final Value<String?> link;
  final Value<int> rowid;
  const WishesCompanion({
    this.id = const Value.absent(),
    this.shopId = const Value.absent(),
    this.osmId = const Value.absent(),
    this.name = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.dataSource = const Value.absent(),
    this.trigger = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.fulfilledVisitId = const Value.absent(),
    this.link = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WishesCompanion.insert({
    required String id,
    this.shopId = const Value.absent(),
    this.osmId = const Value.absent(),
    required String name,
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.dataSource = const Value.absent(),
    this.trigger = const Value.absent(),
    this.note = const Value.absent(),
    required DateTime createdAt,
    this.fulfilledVisitId = const Value.absent(),
    this.link = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<Wish> custom({
    Expression<String>? id,
    Expression<String>? shopId,
    Expression<String>? osmId,
    Expression<String>? name,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<String>? dataSource,
    Expression<String>? trigger,
    Expression<String>? note,
    Expression<DateTime>? createdAt,
    Expression<String>? fulfilledVisitId,
    Expression<String>? link,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (shopId != null) 'shop_id': shopId,
      if (osmId != null) 'osm_id': osmId,
      if (name != null) 'name': name,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (dataSource != null) 'data_source': dataSource,
      if (trigger != null) 'trigger': trigger,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt,
      if (fulfilledVisitId != null) 'fulfilled_visit_id': fulfilledVisitId,
      if (link != null) 'link': link,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WishesCompanion copyWith({
    Value<String>? id,
    Value<String?>? shopId,
    Value<String?>? osmId,
    Value<String>? name,
    Value<double?>? latitude,
    Value<double?>? longitude,
    Value<ShopSource?>? dataSource,
    Value<String>? trigger,
    Value<String>? note,
    Value<DateTime>? createdAt,
    Value<String?>? fulfilledVisitId,
    Value<String?>? link,
    Value<int>? rowid,
  }) {
    return WishesCompanion(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      osmId: osmId ?? this.osmId,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      dataSource: dataSource ?? this.dataSource,
      trigger: trigger ?? this.trigger,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      fulfilledVisitId: fulfilledVisitId ?? this.fulfilledVisitId,
      link: link ?? this.link,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (shopId.present) {
      map['shop_id'] = Variable<String>(shopId.value);
    }
    if (osmId.present) {
      map['osm_id'] = Variable<String>(osmId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (dataSource.present) {
      map['data_source'] = Variable<String>(
        $WishesTable.$converterdataSourcen.toSql(dataSource.value),
      );
    }
    if (trigger.present) {
      map['trigger'] = Variable<String>(trigger.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (fulfilledVisitId.present) {
      map['fulfilled_visit_id'] = Variable<String>(fulfilledVisitId.value);
    }
    if (link.present) {
      map['link'] = Variable<String>(link.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WishesCompanion(')
          ..write('id: $id, ')
          ..write('shopId: $shopId, ')
          ..write('osmId: $osmId, ')
          ..write('name: $name, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('dataSource: $dataSource, ')
          ..write('trigger: $trigger, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('fulfilledVisitId: $fulfilledVisitId, ')
          ..write('link: $link, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HomeBaseSettingsTable extends HomeBaseSettings
    with TableInfo<$HomeBaseSettingsTable, HomeBaseSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HomeBaseSettingsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _latitudeMeta = const VerificationMeta(
    'latitude',
  );
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
    'latitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _longitudeMeta = const VerificationMeta(
    'longitude',
  );
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
    'longitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _setAtMeta = const VerificationMeta('setAt');
  @override
  late final GeneratedColumn<DateTime> setAt = GeneratedColumn<DateTime>(
    'set_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, latitude, longitude, setAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'home_base_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<HomeBaseSetting> instance, {
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
    if (data.containsKey('latitude')) {
      context.handle(
        _latitudeMeta,
        latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta),
      );
    } else if (isInserting) {
      context.missing(_latitudeMeta);
    }
    if (data.containsKey('longitude')) {
      context.handle(
        _longitudeMeta,
        longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta),
      );
    } else if (isInserting) {
      context.missing(_longitudeMeta);
    }
    if (data.containsKey('set_at')) {
      context.handle(
        _setAtMeta,
        setAt.isAcceptableOrUnknown(data['set_at']!, _setAtMeta),
      );
    } else if (isInserting) {
      context.missing(_setAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HomeBaseSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HomeBaseSetting(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      latitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}latitude'],
      )!,
      longitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}longitude'],
      )!,
      setAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}set_at'],
      )!,
    );
  }

  @override
  $HomeBaseSettingsTable createAlias(String alias) {
    return $HomeBaseSettingsTable(attachedDatabase, alias);
  }
}

class HomeBaseSettingsCompanion extends UpdateCompanion<HomeBaseSetting> {
  final Value<String> id;
  final Value<String> name;
  final Value<double> latitude;
  final Value<double> longitude;
  final Value<DateTime> setAt;
  final Value<int> rowid;
  const HomeBaseSettingsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.setAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HomeBaseSettingsCompanion.insert({
    required String id,
    required String name,
    required double latitude,
    required double longitude,
    required DateTime setAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       latitude = Value(latitude),
       longitude = Value(longitude),
       setAt = Value(setAt);
  static Insertable<HomeBaseSetting> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<DateTime>? setAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (setAt != null) 'set_at': setAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HomeBaseSettingsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<double>? latitude,
    Value<double>? longitude,
    Value<DateTime>? setAt,
    Value<int>? rowid,
  }) {
    return HomeBaseSettingsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      setAt: setAt ?? this.setAt,
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
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (setAt.present) {
      map['set_at'] = Variable<DateTime>(setAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HomeBaseSettingsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('setAt: $setAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ShopsTable shops = $ShopsTable(this);
  late final $VisitsTable visits = $VisitsTable(this);
  late final $ActiveCheckinsTable activeCheckins = $ActiveCheckinsTable(this);
  late final $WishesTable wishes = $WishesTable(this);
  late final $HomeBaseSettingsTable homeBaseSettings = $HomeBaseSettingsTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    shops,
    visits,
    activeCheckins,
    wishes,
    homeBaseSettings,
  ];
}

typedef $$ShopsTableCreateCompanionBuilder = ShopsCompanion Function({
  required String id,
  required String name,
  Value<double?> latitude,
  Value<double?> longitude,
  Value<String?> osmId,
  Value<bool> isFamous,
  Value<String> strategyMemo,
  Value<ShopSource?> dataSource,
  Value<String?> area,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$ShopsTableUpdateCompanionBuilder = ShopsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<double?> latitude,
  Value<double?> longitude,
  Value<String?> osmId,
  Value<bool> isFamous,
  Value<String> strategyMemo,
  Value<ShopSource?> dataSource,
  Value<String?> area,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

final class $$ShopsTableReferences
    extends BaseReferences<_$AppDatabase, $ShopsTable, Shop> {
  $$ShopsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$VisitsTable, List<Visit>> _visitsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.visits,
    aliasName: 'shops__id__visits__shop_id',
  );

  $$VisitsTableProcessedTableManager get visitsRefs {
    final manager = $$VisitsTableTableManager(
      $_db,
      $_db.visits,
    ).filter((f) => f.shopId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_visitsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ShopsTableFilterComposer extends Composer<_$AppDatabase, $ShopsTable> {
  $$ShopsTableFilterComposer({
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

  ColumnFilters<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get osmId => $composableBuilder(
    column: $table.osmId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFamous => $composableBuilder(
    column: $table.isFamous,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get strategyMemo => $composableBuilder(
    column: $table.strategyMemo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ShopSource?, ShopSource, String>
  get dataSource => $composableBuilder(
    column: $table.dataSource,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get area => $composableBuilder(
    column: $table.area,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> visitsRefs(
    Expression<bool> Function($$VisitsTableFilterComposer f) f,
  ) {
    final $$VisitsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.visits,
      getReferencedColumn: (t) => t.shopId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VisitsTableFilterComposer(
            $db: $db,
            $table: $db.visits,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ShopsTableOrderingComposer
    extends Composer<_$AppDatabase, $ShopsTable> {
  $$ShopsTableOrderingComposer({
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

  ColumnOrderings<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get osmId => $composableBuilder(
    column: $table.osmId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFamous => $composableBuilder(
    column: $table.isFamous,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get strategyMemo => $composableBuilder(
    column: $table.strategyMemo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dataSource => $composableBuilder(
    column: $table.dataSource,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get area => $composableBuilder(
    column: $table.area,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ShopsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ShopsTable> {
  $$ShopsTableAnnotationComposer({
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

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<String> get osmId =>
      $composableBuilder(column: $table.osmId, builder: (column) => column);

  GeneratedColumn<bool> get isFamous =>
      $composableBuilder(column: $table.isFamous, builder: (column) => column);

  GeneratedColumn<String> get strategyMemo => $composableBuilder(
    column: $table.strategyMemo,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<ShopSource?, String> get dataSource =>
      $composableBuilder(
        column: $table.dataSource,
        builder: (column) => column,
      );

  GeneratedColumn<String> get area =>
      $composableBuilder(column: $table.area, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> visitsRefs<T extends Object>(
    Expression<T> Function($$VisitsTableAnnotationComposer a) f,
  ) {
    final $$VisitsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.visits,
      getReferencedColumn: (t) => t.shopId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VisitsTableAnnotationComposer(
            $db: $db,
            $table: $db.visits,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ShopsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ShopsTable,
          Shop,
          $$ShopsTableFilterComposer,
          $$ShopsTableOrderingComposer,
          $$ShopsTableAnnotationComposer,
          $$ShopsTableCreateCompanionBuilder,
          $$ShopsTableUpdateCompanionBuilder,
          (Shop, $$ShopsTableReferences),
          Shop,
          PrefetchHooks Function({bool visitsRefs})
        > {
  $$ShopsTableTableManager(_$AppDatabase db, $ShopsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ShopsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ShopsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ShopsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double?> latitude = const Value.absent(),
                Value<double?> longitude = const Value.absent(),
                Value<String?> osmId = const Value.absent(),
                Value<bool> isFamous = const Value.absent(),
                Value<String> strategyMemo = const Value.absent(),
                Value<ShopSource?> dataSource = const Value.absent(),
                Value<String?> area = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ShopsCompanion(
                id: id,
                name: name,
                latitude: latitude,
                longitude: longitude,
                osmId: osmId,
                isFamous: isFamous,
                strategyMemo: strategyMemo,
                dataSource: dataSource,
                area: area,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<double?> latitude = const Value.absent(),
                Value<double?> longitude = const Value.absent(),
                Value<String?> osmId = const Value.absent(),
                Value<bool> isFamous = const Value.absent(),
                Value<String> strategyMemo = const Value.absent(),
                Value<ShopSource?> dataSource = const Value.absent(),
                Value<String?> area = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ShopsCompanion.insert(
                id: id,
                name: name,
                latitude: latitude,
                longitude: longitude,
                osmId: osmId,
                isFamous: isFamous,
                strategyMemo: strategyMemo,
                dataSource: dataSource,
                area: area,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ShopsTable, Shop>(table),
                  $$ShopsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({visitsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (visitsRefs) db.visits],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (visitsRefs)
                    await $_getPrefetchedData<Shop, $ShopsTable, Visit>(
                      currentTable: table,
                      referencedTable: $$ShopsTableReferences._visitsRefsTable(
                        db,
                      ),
                      managerFromTypedResult: (p0) =>
                          $$ShopsTableReferences(db, table, p0).visitsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.shopId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ShopsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ShopsTable,
      Shop,
      $$ShopsTableFilterComposer,
      $$ShopsTableOrderingComposer,
      $$ShopsTableAnnotationComposer,
      $$ShopsTableCreateCompanionBuilder,
      $$ShopsTableUpdateCompanionBuilder,
      (Shop, $$ShopsTableReferences),
      Shop,
      PrefetchHooks Function({bool visitsRefs})
    >;
typedef $$VisitsTableCreateCompanionBuilder = VisitsCompanion Function({
  required String id,
  required String shopId,
  required VisitResult result,
  Value<String?> photoPath,
  Value<DateTime?> checkedInAt,
  required DateTime eatenAt,
  Value<RamenStyle?> style,
  Value<int?> rating,
  Value<bool> isLimited,
  Value<String> memo,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$VisitsTableUpdateCompanionBuilder = VisitsCompanion Function({
  Value<String> id,
  Value<String> shopId,
  Value<VisitResult> result,
  Value<String?> photoPath,
  Value<DateTime?> checkedInAt,
  Value<DateTime> eatenAt,
  Value<RamenStyle?> style,
  Value<int?> rating,
  Value<bool> isLimited,
  Value<String> memo,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

final class $$VisitsTableReferences
    extends BaseReferences<_$AppDatabase, $VisitsTable, Visit> {
  $$VisitsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ShopsTable _shopIdTable(_$AppDatabase db) =>
      db.shops.createAlias('visits__shop_id__shops__id');

  $$ShopsTableProcessedTableManager get shopId {
    final $_column = $_itemColumn<String>('shop_id')!;

    final manager = $$ShopsTableTableManager(
      $_db,
      $_db.shops,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_shopIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$VisitsTableFilterComposer
    extends Composer<_$AppDatabase, $VisitsTable> {
  $$VisitsTableFilterComposer({
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

  ColumnWithTypeConverterFilters<VisitResult, VisitResult, String> get result =>
      $composableBuilder(
        column: $table.result,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get photoPath => $composableBuilder(
    column: $table.photoPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get checkedInAt => $composableBuilder(
    column: $table.checkedInAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get eatenAt => $composableBuilder(
    column: $table.eatenAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<RamenStyle?, RamenStyle, String> get style =>
      $composableBuilder(
        column: $table.style,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isLimited => $composableBuilder(
    column: $table.isLimited,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get memo => $composableBuilder(
    column: $table.memo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ShopsTableFilterComposer get shopId {
    final $$ShopsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.shopId,
      referencedTable: $db.shops,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShopsTableFilterComposer(
            $db: $db,
            $table: $db.shops,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$VisitsTableOrderingComposer
    extends Composer<_$AppDatabase, $VisitsTable> {
  $$VisitsTableOrderingComposer({
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

  ColumnOrderings<String> get result => $composableBuilder(
    column: $table.result,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get photoPath => $composableBuilder(
    column: $table.photoPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get checkedInAt => $composableBuilder(
    column: $table.checkedInAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get eatenAt => $composableBuilder(
    column: $table.eatenAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get style => $composableBuilder(
    column: $table.style,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isLimited => $composableBuilder(
    column: $table.isLimited,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get memo => $composableBuilder(
    column: $table.memo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ShopsTableOrderingComposer get shopId {
    final $$ShopsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.shopId,
      referencedTable: $db.shops,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShopsTableOrderingComposer(
            $db: $db,
            $table: $db.shops,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$VisitsTableAnnotationComposer
    extends Composer<_$AppDatabase, $VisitsTable> {
  $$VisitsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<VisitResult, String> get result =>
      $composableBuilder(column: $table.result, builder: (column) => column);

  GeneratedColumn<String> get photoPath =>
      $composableBuilder(column: $table.photoPath, builder: (column) => column);

  GeneratedColumn<DateTime> get checkedInAt => $composableBuilder(
    column: $table.checkedInAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get eatenAt =>
      $composableBuilder(column: $table.eatenAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<RamenStyle?, String> get style =>
      $composableBuilder(column: $table.style, builder: (column) => column);

  GeneratedColumn<int> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => column);

  GeneratedColumn<bool> get isLimited =>
      $composableBuilder(column: $table.isLimited, builder: (column) => column);

  GeneratedColumn<String> get memo =>
      $composableBuilder(column: $table.memo, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$ShopsTableAnnotationComposer get shopId {
    final $$ShopsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.shopId,
      referencedTable: $db.shops,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShopsTableAnnotationComposer(
            $db: $db,
            $table: $db.shops,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$VisitsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VisitsTable,
          Visit,
          $$VisitsTableFilterComposer,
          $$VisitsTableOrderingComposer,
          $$VisitsTableAnnotationComposer,
          $$VisitsTableCreateCompanionBuilder,
          $$VisitsTableUpdateCompanionBuilder,
          (Visit, $$VisitsTableReferences),
          Visit,
          PrefetchHooks Function({bool shopId})
        > {
  $$VisitsTableTableManager(_$AppDatabase db, $VisitsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VisitsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VisitsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VisitsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> shopId = const Value.absent(),
                Value<VisitResult> result = const Value.absent(),
                Value<String?> photoPath = const Value.absent(),
                Value<DateTime?> checkedInAt = const Value.absent(),
                Value<DateTime> eatenAt = const Value.absent(),
                Value<RamenStyle?> style = const Value.absent(),
                Value<int?> rating = const Value.absent(),
                Value<bool> isLimited = const Value.absent(),
                Value<String> memo = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VisitsCompanion(
                id: id,
                shopId: shopId,
                result: result,
                photoPath: photoPath,
                checkedInAt: checkedInAt,
                eatenAt: eatenAt,
                style: style,
                rating: rating,
                isLimited: isLimited,
                memo: memo,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String shopId,
                required VisitResult result,
                Value<String?> photoPath = const Value.absent(),
                Value<DateTime?> checkedInAt = const Value.absent(),
                required DateTime eatenAt,
                Value<RamenStyle?> style = const Value.absent(),
                Value<int?> rating = const Value.absent(),
                Value<bool> isLimited = const Value.absent(),
                Value<String> memo = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => VisitsCompanion.insert(
                id: id,
                shopId: shopId,
                result: result,
                photoPath: photoPath,
                checkedInAt: checkedInAt,
                eatenAt: eatenAt,
                style: style,
                rating: rating,
                isLimited: isLimited,
                memo: memo,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$VisitsTable, Visit>(table),
                  $$VisitsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({shopId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (shopId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.shopId,
                        referencedTable: $$VisitsTableReferences._shopIdTable(
                          db,
                        ),
                        referencedColumn: $$VisitsTableReferences
                            ._shopIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$VisitsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VisitsTable,
      Visit,
      $$VisitsTableFilterComposer,
      $$VisitsTableOrderingComposer,
      $$VisitsTableAnnotationComposer,
      $$VisitsTableCreateCompanionBuilder,
      $$VisitsTableUpdateCompanionBuilder,
      (Visit, $$VisitsTableReferences),
      Visit,
      PrefetchHooks Function({bool shopId})
    >;
typedef $$ActiveCheckinsTableCreateCompanionBuilder =
    ActiveCheckinsCompanion Function({
      Value<int> id,
      Value<String?> shopId,
      Value<String?> osmId,
      required String name,
      Value<double?> latitude,
      Value<double?> longitude,
      Value<ShopSource?> dataSource,
      required DateTime checkedInAt,
    });
typedef $$ActiveCheckinsTableUpdateCompanionBuilder =
    ActiveCheckinsCompanion Function({
      Value<int> id,
      Value<String?> shopId,
      Value<String?> osmId,
      Value<String> name,
      Value<double?> latitude,
      Value<double?> longitude,
      Value<ShopSource?> dataSource,
      Value<DateTime> checkedInAt,
    });

class $$ActiveCheckinsTableFilterComposer
    extends Composer<_$AppDatabase, $ActiveCheckinsTable> {
  $$ActiveCheckinsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get shopId => $composableBuilder(
    column: $table.shopId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get osmId => $composableBuilder(
    column: $table.osmId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ShopSource?, ShopSource, String>
  get dataSource => $composableBuilder(
    column: $table.dataSource,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<DateTime> get checkedInAt => $composableBuilder(
    column: $table.checkedInAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ActiveCheckinsTableOrderingComposer
    extends Composer<_$AppDatabase, $ActiveCheckinsTable> {
  $$ActiveCheckinsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get shopId => $composableBuilder(
    column: $table.shopId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get osmId => $composableBuilder(
    column: $table.osmId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dataSource => $composableBuilder(
    column: $table.dataSource,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get checkedInAt => $composableBuilder(
    column: $table.checkedInAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ActiveCheckinsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ActiveCheckinsTable> {
  $$ActiveCheckinsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get shopId =>
      $composableBuilder(column: $table.shopId, builder: (column) => column);

  GeneratedColumn<String> get osmId =>
      $composableBuilder(column: $table.osmId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ShopSource?, String> get dataSource =>
      $composableBuilder(
        column: $table.dataSource,
        builder: (column) => column,
      );

  GeneratedColumn<DateTime> get checkedInAt => $composableBuilder(
    column: $table.checkedInAt,
    builder: (column) => column,
  );
}

class $$ActiveCheckinsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ActiveCheckinsTable,
          ActiveCheckin,
          $$ActiveCheckinsTableFilterComposer,
          $$ActiveCheckinsTableOrderingComposer,
          $$ActiveCheckinsTableAnnotationComposer,
          $$ActiveCheckinsTableCreateCompanionBuilder,
          $$ActiveCheckinsTableUpdateCompanionBuilder,
          (
            ActiveCheckin,
            BaseReferences<_$AppDatabase, $ActiveCheckinsTable, ActiveCheckin>,
          ),
          ActiveCheckin,
          PrefetchHooks Function()
        > {
  $$ActiveCheckinsTableTableManager(
    _$AppDatabase db,
    $ActiveCheckinsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ActiveCheckinsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ActiveCheckinsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ActiveCheckinsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> shopId = const Value.absent(),
                Value<String?> osmId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double?> latitude = const Value.absent(),
                Value<double?> longitude = const Value.absent(),
                Value<ShopSource?> dataSource = const Value.absent(),
                Value<DateTime> checkedInAt = const Value.absent(),
              }) => ActiveCheckinsCompanion(
                id: id,
                shopId: shopId,
                osmId: osmId,
                name: name,
                latitude: latitude,
                longitude: longitude,
                dataSource: dataSource,
                checkedInAt: checkedInAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> shopId = const Value.absent(),
                Value<String?> osmId = const Value.absent(),
                required String name,
                Value<double?> latitude = const Value.absent(),
                Value<double?> longitude = const Value.absent(),
                Value<ShopSource?> dataSource = const Value.absent(),
                required DateTime checkedInAt,
              }) => ActiveCheckinsCompanion.insert(
                id: id,
                shopId: shopId,
                osmId: osmId,
                name: name,
                latitude: latitude,
                longitude: longitude,
                dataSource: dataSource,
                checkedInAt: checkedInAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ActiveCheckinsTable, ActiveCheckin>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ActiveCheckinsTable,
                    ActiveCheckin
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ActiveCheckinsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ActiveCheckinsTable,
      ActiveCheckin,
      $$ActiveCheckinsTableFilterComposer,
      $$ActiveCheckinsTableOrderingComposer,
      $$ActiveCheckinsTableAnnotationComposer,
      $$ActiveCheckinsTableCreateCompanionBuilder,
      $$ActiveCheckinsTableUpdateCompanionBuilder,
      (
        ActiveCheckin,
        BaseReferences<_$AppDatabase, $ActiveCheckinsTable, ActiveCheckin>,
      ),
      ActiveCheckin,
      PrefetchHooks Function()
    >;
typedef $$WishesTableCreateCompanionBuilder = WishesCompanion Function({
  required String id,
  Value<String?> shopId,
  Value<String?> osmId,
  required String name,
  Value<double?> latitude,
  Value<double?> longitude,
  Value<ShopSource?> dataSource,
  Value<String> trigger,
  Value<String> note,
  required DateTime createdAt,
  Value<String?> fulfilledVisitId,
  Value<String?> link,
  Value<int> rowid,
});
typedef $$WishesTableUpdateCompanionBuilder = WishesCompanion Function({
  Value<String> id,
  Value<String?> shopId,
  Value<String?> osmId,
  Value<String> name,
  Value<double?> latitude,
  Value<double?> longitude,
  Value<ShopSource?> dataSource,
  Value<String> trigger,
  Value<String> note,
  Value<DateTime> createdAt,
  Value<String?> fulfilledVisitId,
  Value<String?> link,
  Value<int> rowid,
});

class $$WishesTableFilterComposer
    extends Composer<_$AppDatabase, $WishesTable> {
  $$WishesTableFilterComposer({
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

  ColumnFilters<String> get shopId => $composableBuilder(
    column: $table.shopId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get osmId => $composableBuilder(
    column: $table.osmId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ShopSource?, ShopSource, String>
  get dataSource => $composableBuilder(
    column: $table.dataSource,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get trigger => $composableBuilder(
    column: $table.trigger,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fulfilledVisitId => $composableBuilder(
    column: $table.fulfilledVisitId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get link => $composableBuilder(
    column: $table.link,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WishesTableOrderingComposer
    extends Composer<_$AppDatabase, $WishesTable> {
  $$WishesTableOrderingComposer({
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

  ColumnOrderings<String> get shopId => $composableBuilder(
    column: $table.shopId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get osmId => $composableBuilder(
    column: $table.osmId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dataSource => $composableBuilder(
    column: $table.dataSource,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trigger => $composableBuilder(
    column: $table.trigger,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fulfilledVisitId => $composableBuilder(
    column: $table.fulfilledVisitId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get link => $composableBuilder(
    column: $table.link,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WishesTableAnnotationComposer
    extends Composer<_$AppDatabase, $WishesTable> {
  $$WishesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get shopId =>
      $composableBuilder(column: $table.shopId, builder: (column) => column);

  GeneratedColumn<String> get osmId =>
      $composableBuilder(column: $table.osmId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ShopSource?, String> get dataSource =>
      $composableBuilder(
        column: $table.dataSource,
        builder: (column) => column,
      );

  GeneratedColumn<String> get trigger =>
      $composableBuilder(column: $table.trigger, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get fulfilledVisitId => $composableBuilder(
    column: $table.fulfilledVisitId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get link =>
      $composableBuilder(column: $table.link, builder: (column) => column);
}

class $$WishesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WishesTable,
          Wish,
          $$WishesTableFilterComposer,
          $$WishesTableOrderingComposer,
          $$WishesTableAnnotationComposer,
          $$WishesTableCreateCompanionBuilder,
          $$WishesTableUpdateCompanionBuilder,
          (Wish, BaseReferences<_$AppDatabase, $WishesTable, Wish>),
          Wish,
          PrefetchHooks Function()
        > {
  $$WishesTableTableManager(_$AppDatabase db, $WishesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WishesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WishesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WishesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> shopId = const Value.absent(),
                Value<String?> osmId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double?> latitude = const Value.absent(),
                Value<double?> longitude = const Value.absent(),
                Value<ShopSource?> dataSource = const Value.absent(),
                Value<String> trigger = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String?> fulfilledVisitId = const Value.absent(),
                Value<String?> link = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WishesCompanion(
                id: id,
                shopId: shopId,
                osmId: osmId,
                name: name,
                latitude: latitude,
                longitude: longitude,
                dataSource: dataSource,
                trigger: trigger,
                note: note,
                createdAt: createdAt,
                fulfilledVisitId: fulfilledVisitId,
                link: link,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> shopId = const Value.absent(),
                Value<String?> osmId = const Value.absent(),
                required String name,
                Value<double?> latitude = const Value.absent(),
                Value<double?> longitude = const Value.absent(),
                Value<ShopSource?> dataSource = const Value.absent(),
                Value<String> trigger = const Value.absent(),
                Value<String> note = const Value.absent(),
                required DateTime createdAt,
                Value<String?> fulfilledVisitId = const Value.absent(),
                Value<String?> link = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WishesCompanion.insert(
                id: id,
                shopId: shopId,
                osmId: osmId,
                name: name,
                latitude: latitude,
                longitude: longitude,
                dataSource: dataSource,
                trigger: trigger,
                note: note,
                createdAt: createdAt,
                fulfilledVisitId: fulfilledVisitId,
                link: link,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WishesTable, Wish>(table),
                  BaseReferences<_$AppDatabase, $WishesTable, Wish>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WishesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WishesTable,
      Wish,
      $$WishesTableFilterComposer,
      $$WishesTableOrderingComposer,
      $$WishesTableAnnotationComposer,
      $$WishesTableCreateCompanionBuilder,
      $$WishesTableUpdateCompanionBuilder,
      (Wish, BaseReferences<_$AppDatabase, $WishesTable, Wish>),
      Wish,
      PrefetchHooks Function()
    >;
typedef $$HomeBaseSettingsTableCreateCompanionBuilder =
    HomeBaseSettingsCompanion Function({
      required String id,
      required String name,
      required double latitude,
      required double longitude,
      required DateTime setAt,
      Value<int> rowid,
    });
typedef $$HomeBaseSettingsTableUpdateCompanionBuilder =
    HomeBaseSettingsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<double> latitude,
      Value<double> longitude,
      Value<DateTime> setAt,
      Value<int> rowid,
    });

class $$HomeBaseSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $HomeBaseSettingsTable> {
  $$HomeBaseSettingsTableFilterComposer({
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

  ColumnFilters<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get setAt => $composableBuilder(
    column: $table.setAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HomeBaseSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $HomeBaseSettingsTable> {
  $$HomeBaseSettingsTableOrderingComposer({
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

  ColumnOrderings<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get setAt => $composableBuilder(
    column: $table.setAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HomeBaseSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $HomeBaseSettingsTable> {
  $$HomeBaseSettingsTableAnnotationComposer({
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

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<DateTime> get setAt =>
      $composableBuilder(column: $table.setAt, builder: (column) => column);
}

class $$HomeBaseSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HomeBaseSettingsTable,
          HomeBaseSetting,
          $$HomeBaseSettingsTableFilterComposer,
          $$HomeBaseSettingsTableOrderingComposer,
          $$HomeBaseSettingsTableAnnotationComposer,
          $$HomeBaseSettingsTableCreateCompanionBuilder,
          $$HomeBaseSettingsTableUpdateCompanionBuilder,
          (
            HomeBaseSetting,
            BaseReferences<
              _$AppDatabase,
              $HomeBaseSettingsTable,
              HomeBaseSetting
            >,
          ),
          HomeBaseSetting,
          PrefetchHooks Function()
        > {
  $$HomeBaseSettingsTableTableManager(
    _$AppDatabase db,
    $HomeBaseSettingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HomeBaseSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HomeBaseSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HomeBaseSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double> latitude = const Value.absent(),
                Value<double> longitude = const Value.absent(),
                Value<DateTime> setAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HomeBaseSettingsCompanion(
                id: id,
                name: name,
                latitude: latitude,
                longitude: longitude,
                setAt: setAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required double latitude,
                required double longitude,
                required DateTime setAt,
                Value<int> rowid = const Value.absent(),
              }) => HomeBaseSettingsCompanion.insert(
                id: id,
                name: name,
                latitude: latitude,
                longitude: longitude,
                setAt: setAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$HomeBaseSettingsTable, HomeBaseSetting>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $HomeBaseSettingsTable,
                    HomeBaseSetting
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HomeBaseSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HomeBaseSettingsTable,
      HomeBaseSetting,
      $$HomeBaseSettingsTableFilterComposer,
      $$HomeBaseSettingsTableOrderingComposer,
      $$HomeBaseSettingsTableAnnotationComposer,
      $$HomeBaseSettingsTableCreateCompanionBuilder,
      $$HomeBaseSettingsTableUpdateCompanionBuilder,
      (
        HomeBaseSetting,
        BaseReferences<_$AppDatabase, $HomeBaseSettingsTable, HomeBaseSetting>,
      ),
      HomeBaseSetting,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ShopsTableTableManager get shops =>
      $$ShopsTableTableManager(_db, _db.shops);
  $$VisitsTableTableManager get visits =>
      $$VisitsTableTableManager(_db, _db.visits);
  $$ActiveCheckinsTableTableManager get activeCheckins =>
      $$ActiveCheckinsTableTableManager(_db, _db.activeCheckins);
  $$WishesTableTableManager get wishes =>
      $$WishesTableTableManager(_db, _db.wishes);
  $$HomeBaseSettingsTableTableManager get homeBaseSettings =>
      $$HomeBaseSettingsTableTableManager(_db, _db.homeBaseSettings);
}
