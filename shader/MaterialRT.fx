/// @file
/// @brief オフスクリーンに物理ベースマテリアル値を書き出すためのエフェクト。
/// @author ルーチェ
///
/// 事前に下記のパラメータをマクロ定義することで書き出す値が変わる。
///
/// POSTIBL_PBM_METALLIC  -- メタリック値。未定義時は 0.0f 。
/// POSTIBL_PBM_ROUGHNESS -- ラフネス値。未定義時は 1.0f 。
/// POSTIBL_PBM_SPECULAR  -- スペキュラ値。未定義時は 0.04f 。
/// POSTIBL_PBM_RATIO     -- 反映度合い。未定義時は 1.0f 。

////////////////////
// マクロ定義ここから
////////////////////

// メタリック値。
#ifndef POSTIBL_PBM_METALLIC
#define POSTIBL_PBM_METALLIC 0.0f
#endif // POSTIBL_PBM_METALLIC

// ラフネス値。
#ifndef POSTIBL_PBM_ROUGHNESS
#define POSTIBL_PBM_ROUGHNESS 1.0f
#endif // POSTIBL_PBM_ROUGHNESS

// スペキュラ値。
#ifndef POSTIBL_PBM_SPECULAR
#define POSTIBL_PBM_SPECULAR 0.04f
#endif // POSTIBL_PBM_SPECULAR

// 反映度合い。
#ifndef POSTIBL_PBM_RATIO
#define POSTIBL_PBM_RATIO 1.0f
#endif // POSTIBL_PBM_RATIO

////////////////////
// マクロ定義ここまで
////////////////////
// 変数定義ここから
////////////////////

/// ワールドビュープロジェクションマトリクス。
float4x4 WorldViewProjMatrix : WORLDVIEWPROJECTION;

/// ワールドマトリクス。
float4x4 WorldMatrix : WORLD;

#ifdef MIKUMIKUMOVING

/// ワールドビューマトリクス。
float4x4 WorldViewMatrix : WORLDVIEW;

/// プロジェクションマトリクス。
float4x4 ProjMatrix : PROJECTION;

/// ワールド空間上のカメラ位置。
float3 CameraPosition : POSITION < string Object = "Camera"; >;

#endif // MIKUMIKUMOVING

////////////////////
// 変数定義ここまで
////////////////////
// シェーダ処理ここから
////////////////////

/// 頂点シェーダの出力構造体。
struct VSOutput
{
    float4 pos : POSITION;  ///< 位置。
};

/// 頂点シェーダ処理を行う。
#ifdef MIKUMIKUMOVING
VSOutput RunVS(MMM_SKINNING_INPUT mmmIn)
#else // MIKUMIKUMOVING
VSOutput RunVS(float4 pos : POSITION)
#endif // MIKUMIKUMOVING
{
    VSOutput vsOut = (VSOutput)0;

#ifdef MIKUMIKUMOVING
    float4 pos =
        MMM_SkinnedPosition(
            mmmIn.Pos,
            mmmIn.BlendWeight,
            mmmIn.BlendIndices,
            mmmIn.SdefC,
            mmmIn.SdefR0,
            mmmIn.SdefR1);
#endif // MIKUMIKUMOVING

    float4x4 wvp = WorldViewProjMatrix;

#ifdef MIKUMIKUMOVING
    if (MMM_IsDinamicProjection)
    {
        float3 eye = CameraPosition - mul(pos, WorldMatrix).xyz;
        wvp = mul(WorldViewMatrix, MMM_DynamicFov(ProjMatrix, length(eye)));
    }
#endif // MIKUMIKUMOVING

    vsOut.pos = mul(pos, wvp);

    return vsOut;
}

/// ピクセルシェーダ処理を行う。
float4 RunPS() : COLOR
{
    // 物理ベースマテリアル値を格納して返す
    return
        float4(
            POSTIBL_PBM_METALLIC,
            POSTIBL_PBM_ROUGHNESS,
            POSTIBL_PBM_SPECULAR,
            POSTIBL_PBM_RATIO);
}

/// オブジェクト描画テクニック定義。
technique ObjectTec < string MMDPass = "object"; >
{
    pass ObjectPass
    {
        AlphaBlendEnable = false;
        AlphaTestEnable = false;
        VertexShader = compile vs_3_0 RunVS();
        PixelShader = compile ps_3_0 RunPS();
    }
}

/// セルフシャドウ付きオブジェクト描画テクニック定義。
technique ObjectSSTec < string MMDPass = "object_ss"; >
{
    pass ObjectSSPass
    {
        AlphaBlendEnable = false;
        AlphaTestEnable = false;
        VertexShader = compile vs_3_0 RunVS();
        PixelShader = compile ps_3_0 RunPS();
    }
}

// 輪郭等は描画しない
technique EdgeTec < string MMDPass = "edge"; > { }
technique ShadowTec < string MMDPass = "shadow"; > { }
technique ZPlotTec < string MMDPass = "zplot"; > { }

////////////////////
// シェーダ処理ここまで
////////////////////
