# NJUPT Flutter

南邮校园服务 Flutter 客户端，通过 [flutter_rust_bridge](https://github.com/fzyzcjy/flutter_rust_bridge) 调用仓库 [`njupt-rs`](https://github.com/kingpoem/njupt-rs)。

## 布局

```
github/
├── njupt-rs/           # Rust API（独立仓库）
└── njupt-flutter/
    ├── lib/            # Dart UI
    ├── rust/           # FRB 桥接，Cargo 依赖 path = ../../njupt-rs
    └── rust_builder/   # Cargokit 构建胶水
```

## 功能

- 登录：校内 SSO / 校外 WebVPN；同时登录教务与校园卡
- 缓存：默认 `cacheFirst`；下拉或「强制刷新」走 `networkOnly`
- 教务：课表、成绩、成绩分项、考试/补考/缓考、已选课程、学籍、选课浏览（只读）
- 校园卡：余额查询

## 开发

```bash
# 需先有同级目录的 njupt-rs
flutter_rust_bridge_codegen generate
flutter run -d macos   # 或其他设备
```

密码仅用于登录会话，不会写入本地；学号与校内外偏好会保存在 SharedPreferences。
