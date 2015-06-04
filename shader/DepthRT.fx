/// @file
/// @brief オフスクリーンに深度値を書き出すためのエフェクト。
/// @author ルーチェ

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
    float4 pos : POSITION;      ///< 位置。
    float4 cpos : TEXCOORD0;    ///< 深度値計算用の位置。
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
    vsOut.cpos = vsOut.pos;

    return vsOut;
}

/// ピクセルシェーダ処理を行う。
float4 RunPS(float4 cpos : TEXCOORD0) : COLOR
{
    // 深度値を格納して返す
    float4 color = { 0, 0, 0, 1 };
    color.r = cpos.z / cpos.w;
    return color;
}

/// オブジェクト描画テクニック定義。
technique ObjectTec < string MMDPass = "object"; >
{
    pass ObjectPass
    {
        AlphaBlendEnable = false;
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
