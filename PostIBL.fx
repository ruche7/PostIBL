/// @file
/// @brief IBLポストエフェクトのメインファイル。
/// @author ルーチェ

// 環境マップ関連定義
#include "shader/envmap_def.h"

////////////////////
// 設定ここから
////////////////////

/// 通常描画結果記録用テクスチャのフォーマット。
#define POSTIBL_ORGCOLOR_RT_FORMAT "A16B16G16R16F"

/// 物理ベースマテリアルマップテクスチャのフォーマット。
#define POSTIBL_MATERIAL_RT_FORMAT "A16B16G16R16F"

/// アルベドマップテクスチャのフォーマット。
#define POSTIBL_ALBEDO_RT_FORMAT "A8R8G8B8"

/// 位置マップテクスチャのフォーマット。
#define POSTIBL_POSITION_RT_FORMAT "A16B16G16R16F"

/// 法線マップテクスチャのフォーマット。
#define POSTIBL_NORMAL_RT_FORMAT "A16B16G16R16F"

/// 深度マップテクスチャのフォーマット。
#define POSTIBL_DEPTH_RT_FORMAT "R32F"

////////////////////
// 設定ここまで
////////////////////
// 変数定義ここから
////////////////////

/// ポストエフェクト用定義。
float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8f;

/// デプスバッファテクスチャ。
texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET < string Format = "D24S8"; >;

/// 通常描画結果記録用テクスチャ。
texture2D OrgColorRT : RENDERCOLORTARGET <
    float2 ViewPortRatio = { 1, 1 };
    string Format = POSTIBL_ORGCOLOR_RT_FORMAT;
    int MipLevels = 1; >;

/// 通常描画結果記録用テクスチャのサンプラ。
sampler2D OrgColorRTSampler =
    sampler_state
    {
        Texture = <OrgColorRT>;
        MinFilter = LINEAR;
        MagFilter = LINEAR;
        MipFilter = LINEAR;
        AddressU = CLAMP;
        AddressV = CLAMP;
    };

#if 0
/// 環境マップテクスチャ。
texture2D EnvMapRT : OFFSCREENRENDERTARGET <
    string Description = "Environment map for PostIBL";
    int Width = (POSTIBL_ENVMAP_FACE_SIZE) * 4;
    int Height = (POSTIBL_ENVMAP_FACE_SIZE) * 2;
    float4 ClearColor = { 0, 0, 0, 0 };
    float ClearDepth = 1;
    string Format = POSTIBL_ENVMAP_TEX_FORMAT;
    int MipLevels = 1;
    string DefaultEffect =
        "self=hide;"
        "*=shader/EnvMapRT.fx"; >;

/// 環境マップテクスチャのサンプラ。
sampler2D EnvMapRTSampler =
    sampler_state
    {
        Texture = <EnvMapRT>;
        MinFilter = LINEAR;
        MagFilter = LINEAR;
        MipFilter = LINEAR;
        AddressU = WRAP;
        AddressV = CLAMP;
    };
#endif // 0

/// 物理ベースマテリアルマップテクスチャ。
texture2D IBL_Material : OFFSCREENRENDERTARGET <
    string Description = "Material map for PostIBL";
    float2 ViewPortRatio = { 1, 1 };
    float4 ClearColor = { 0, 0, 0, 0 };
    float ClearDepth = 1;
    string Format = POSTIBL_MATERIAL_RT_FORMAT;
    int MipLevels = 1;
    string DefaultEffect =
        "self=hide;"
        "*_m0r0.0.*=material/metal0_rough0.0.fx;"
        "*_m0r0.1.*=material/metal0_rough0.1.fx;"
        "*_m0r0.2.*=material/metal0_rough0.2.fx;"
        "*_m0r0.3.*=material/metal0_rough0.3.fx;"
        "*_m0r0.4.*=material/metal0_rough0.4.fx;"
        "*_m0r0.5.*=material/metal0_rough0.5.fx;"
        "*_m0r0.6.*=material/metal0_rough0.6.fx;"
        "*_m0r0.7.*=material/metal0_rough0.7.fx;"
        "*_m0r0.8.*=material/metal0_rough0.8.fx;"
        "*_m0r0.9.*=material/metal0_rough0.9.fx;"
        "*_m0r1.0.*=material/metal0_rough1.0.fx;"
        "*_m1r0.0.*=material/metal1_rough0.0.fx;"
        "*_m1r0.1.*=material/metal1_rough0.1.fx;"
        "*_m1r0.2.*=material/metal1_rough0.2.fx;"
        "*_m1r0.3.*=material/metal1_rough0.3.fx;"
        "*_m1r0.4.*=material/metal1_rough0.4.fx;"
        "*_m1r0.5.*=material/metal1_rough0.5.fx;"
        "*_m1r0.6.*=material/metal1_rough0.6.fx;"
        "*_m1r0.7.*=material/metal1_rough0.7.fx;"
        "*_m1r0.8.*=material/metal1_rough0.8.fx;"
        "*_m1r0.9.*=material/metal1_rough0.9.fx;"
        "*_m1r1.0.*=material/metal1_rough1.0.fx;"
        "*=material/none.fx;"; >;

/// 物理ベースマテリアルマップテクスチャのサンプラ。
sampler2D MaterialSampler =
    sampler_state
    {
        Texture = <IBL_Material>;
        MinFilter = LINEAR;
        MagFilter = LINEAR;
        MipFilter = LINEAR;
        AddressU = WRAP;
        AddressV = CLAMP;
    };

/// アルベドマップテクスチャ。
texture2D IBL_Albedo : OFFSCREENRENDERTARGET <
    string Description = "Albedo map for PostIBL";
    float2 ViewPortRatio = { 1, 1 };
    float4 ClearColor = { 0, 0, 0, 0 };
    float ClearDepth = 1;
    string Format = POSTIBL_ALBEDO_RT_FORMAT;
    int MipLevels = 1;
    string DefaultEffect =
        "self=hide;"
        "*=shader/AlbedoRT.fx"; >;

/// アルベドマップテクスチャのサンプラ。
sampler2D AlbedoSampler =
    sampler_state
    {
        Texture = <IBL_Albedo>;
        MinFilter = LINEAR;
        MagFilter = LINEAR;
        MipFilter = LINEAR;
        AddressU = CLAMP;
        AddressV = CLAMP;
    };

/// 位置マップテクスチャ。
texture2D IBL_Position : OFFSCREENRENDERTARGET <
    string Description = "Position map for PostIBL";
    float2 ViewPortRatio = { 1, 1 };
    float4 ClearColor = { 0, 0, 0, 0 };
    float ClearDepth = 1;
    string Format = POSTIBL_POSITION_RT_FORMAT;
    int MipLevels = 1;
    string DefaultEffect =
        "self=hide;"
        "*=shader/PositionRT.fx"; >;

/// 位置マップテクスチャのサンプラ。
sampler2D PositionSampler =
    sampler_state
    {
        Texture = <IBL_Position>;
        MinFilter = LINEAR;
        MagFilter = LINEAR;
        MipFilter = LINEAR;
        AddressU = CLAMP;
        AddressV = CLAMP;
    };

/// 法線マップテクスチャ。
texture2D IBL_Normal : OFFSCREENRENDERTARGET <
    string Description = "Normal map for PostIBL";
    float2 ViewPortRatio = { 1, 1 };
    float4 ClearColor = { 0, 0, 0, 0 };
    float ClearDepth = 1;
    string Format = POSTIBL_NORMAL_RT_FORMAT;
    int MipLevels = 1;
    string DefaultEffect =
        "self=hide;"
        "*=shader/NormalRT.fx"; >;

/// 法線マップテクスチャのサンプラ。
sampler2D NormalSampler =
    sampler_state
    {
        Texture = <IBL_Normal>;
        MinFilter = LINEAR;
        MagFilter = LINEAR;
        MipFilter = LINEAR;
        AddressU = CLAMP;
        AddressV = CLAMP;
    };

/// 深度マップテクスチャ。
texture2D IBL_Depth : OFFSCREENRENDERTARGET <
    string Description = "Depth map for PostIBL";
    float2 ViewPortRatio = { 1, 1 };
    float4 ClearColor = { 0, 0, 0, 0 };
    float ClearDepth = 1;
    string Format = POSTIBL_DEPTH_RT_FORMAT;
    int MipLevels = 1;
    string DefaultEffect =
        "self=hide;"
        "*=shader/DepthRT.fx"; >;

/// 深度マップテクスチャのサンプラ。
sampler2D DepthSampler =
    sampler_state
    {
        Texture = <IBL_Depth>;
        MinFilter = LINEAR;
        MagFilter = LINEAR;
        MipFilter = LINEAR;
        AddressU = CLAMP;
        AddressV = CLAMP;
    };

/// ビューポートサイズ。
float2 ViewportSize : VIEWPORTPIXELSIZE;

/// ビューポートオフセット。
static float2 ViewportOffset = float2(0.5f, 0.5f) / ViewportSize;

/// クリア色。
float4 ClearColor = { 0.6f, 0.6f, 0.6f, 0 };

/// クリア深度。
float ClearDepth = 1;

////////////////////
// 変数定義ここまで
////////////////////
// シェーダ処理ここから
////////////////////

/// 頂点シェーダの出力構造体。
struct VSOutput
{
    float4 pos : POSITION;  ///< 位置。
    float2 tex : TEXCOORD0; ///< テクスチャUV。
};

/// 頂点シェーダ処理を行う。
VSOutput RunVS(float4 pos : POSITION, float2 tex : TEXCOORD0)
{
    VSOutput vsOut = (VSOutput)0;

    vsOut.pos = pos;
    vsOut.tex = tex + ViewportOffset;

    return vsOut;
}

/// ピクセルシェーダ処理を行う。
float4 RunPS(float2 tex : TEXCOORD0) : COLOR
{
    // 元の色を取得
    float4 orgColor = tex2D(OrgColorRTSampler, tex);

    // 物理ベースマテリアル値を取得
    float4 pbm = tex2D(MaterialSampler, tex);
    if (pbm.a <= 0)
    {
        // 物理ベースマテリアル値が設定されていなければ元の色を返す
        return orgColor;
    }
    float metal = pbm.x;
    float rough = pbm.y;
    float specular = pbm.z;

    // アルベド、位置、法線、深度を取得
    float4 albedo = tex2D(AlbedoSampler, tex);
    float3 pos = tex2D(PositionSampler, tex).xyz;
    float3 normal = tex2D(NormalSampler, tex).xyz;
    float depth = tex2D(DepthSampler, tex).r;

    /// @todo ひとまずアルベドを表示してみる。
    float4 color = lerp(orgColor, albedo, pbm.a);

    return color;
}

/// テクニック定義。
technique PostIBLTec <
    string Script =
        "RenderColorTarget0=OrgColorRT;"
        "RenderDepthStencilTarget=DepthBuffer;"
        "ClearSetColor=ClearColor;"
        "ClearSetDepth=ClearDepth;"
        "Clear=Color;"
        "Clear=Depth;"
        "ScriptExternal=Color;"
        "RenderColorTarget0=;"
        "RenderDepthStencilTarget=;"
        "Pass=PostIBLPass;"; >
{
    pass PostIBLPass < string Script= "Draw=Buffer;"; >
    {
        ZEnable = false;
        VertexShader = compile vs_3_0 RunVS();
        PixelShader = compile ps_3_0 RunPS();
    }
}

////////////////////
// シェーダ処理ここまで
////////////////////
