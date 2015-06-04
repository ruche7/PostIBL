/// @file
/// @brief 物理ベースマテリアルマップにマテリアル値を書き出すためのシェーダ。
/// @author ルーチェ
///
/// PostIBL によるレンダリングを適用しない材質に対して用いる。

/// 反映度合い。
#define POSTIBL_PBM_RATIO 0.0f

// 実処理
#include "../shader/MaterialRT.fx"
