/// @file
/// @brief 環境マップの共通定義を行うヘッダ。
/// @author ルーチェ

#ifndef POSTIBL_SHADER_ENVMAP_DEF_H
#define POSTIBL_SHADER_ENVMAP_DEF_H

/// 環境マップの1面あたりの縦横幅。 128 または 256 。
#define POSTIBL_ENVMAP_FACE_SIZE 128

/// 環境マップ各面作成用テクスチャの縦横幅。
#define POSTIBL_ENVMAP_SRC_SIZE 256

/// 環境マップテクスチャのフォーマット。
#define POSTIBL_ENVMAP_TEX_FORMAT "A16B16G16R16F"

#endif // POSTIBL_SHADER_ENVMAP_DEF_H
