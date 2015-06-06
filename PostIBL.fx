/// @file
/// @brief IBLポストエフェクトのメインファイル。
/// @author ルーチェ

// 環境マップ関連定義
#include "shader/EnvMapCommon.h"

////////////////////
// 設定ここから
////////////////////

/// 通常描画結果記録用テクスチャのフォーマット。
#define POSTIBL_ORGCOLOR_RT_FORMAT "A8R8G8B8"

/// 環境マップテクスチャの縦横幅。
///
/// - 512, 1024, 2048 あたり。PCスペックに自信があるなら 4096 もアリ。
/// - 当然ながらサイズが大きいほど綺麗になるが負荷も大きい。
#define POSTIBL_ENVMAP_RT_SIZE 2048

/// 環境カラーマップテクスチャのフォーマット。
#define POSTIBL_ENVCOLOR_RT_FORMAT "A16B16G16R16F"

/// @brief 環境マップ展開先テクスチャの横幅。
///
/// - 512, 1024, 2048 のいずれか。縦幅はこれの半分になる。
/// - 当然ながらサイズが大きいほど綺麗になるが負荷も大きい。
/// - 基本的には POSTIBL_ENVMAP_RT_SIZE と同じかそれより小さくする。
#define POSTIBL_ENVMAP_DEST_WIDTH 1024

/// 環境マップ展開先テクスチャのフォーマット。
#define POSTIBL_ENVMAP_DEST_FORMAT "A16B16G16R16F"

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

/// Hammersley のY座標を事前計算したテクスチャのサンプル数。
#define POSTIBL_HAMMERSLEY_Y_SAMPLE_COUNT 1024

/// SSR+IBLでのサンプリング回数。
#define POSTIBL_REFLECTION_SAMPLE_COUNT 32

/// SSRのレイトレースステップ回数。
#define POSTIBL_SSR_STEP_COUNT 8

/// SSRのレイトレースステップのオフセット量。 -0.5f 以上 +0.5f 以下。
#define POSTIBL_SSR_STEP_OFFSET 0.0f

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

/// 通常描画結果記録用デプスバッファ。
texture2D OrgColorDS : RENDERDEPTHSTENCILTARGET <
    float2 ViewPortRatio = { 1, 1 };
    string Format = "D24S8"; >;

/// 環境カラーマップテクスチャ。
texture2D IBL_EnvColor : OFFSCREENRENDERTARGET <
    string Description = "Environment color map for PostIBL";
    int Width = (POSTIBL_ENVMAP_RT_SIZE);
    int Height = (POSTIBL_ENVMAP_RT_SIZE);
    float4 ClearColor = { 0, 0, 0, 0 };
    float ClearDepth = 1;
    string Format = POSTIBL_ENVCOLOR_RT_FORMAT;
    int MipLevels = 1;
    string DefaultEffect =
        "self=hide;"
#ifdef MIKUMIKUMOVING
        "*=shader/EnvMapRT_MMM.fx";
#else // MIKUMIKUMOVING
        "*=shader/EnvMapRT_MME.fx";
#endif // MIKUMIKUMOVING
    >;

/// 環境カラーマップテクスチャのサンプラ。
sampler2D EnvColorSampler =
    sampler_state
    {
        Texture = <IBL_EnvColor>;
        MinFilter = POINT;
        MagFilter = POINT;
        MipFilter = POINT;
        AddressU = WRAP;
        AddressV = CLAMP;
    };

/// 環境マップ展開先テクスチャ。
texture2D EnvMapRT : RENDERCOLORTARGET <
    int Width = (POSTIBL_ENVMAP_DEST_WIDTH);
    int Height = (POSTIBL_ENVMAP_DEST_WIDTH) / 2;
    string Format = POSTIBL_ENVMAP_DEST_FORMAT;
    int MipLevels = 1; >;

/// 環境マップ展開先テクスチャのサンプラ。
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
    float4 ClearColor = { 1, 1, 1, 0 };
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

/// 環境マップ展開用テクスチャファイルパス作成マクロ。
#define POSTIBL_ENVMAP_DEST_TEXNAME(width) "texture/equirect_to_cube_" #width ".dds"

/// 環境マップ展開用テクスチャ。
texture2D EnvDestTex <
    string ResourceName = POSTIBL_ENVMAP_DEST_TEXNAME(POSTIBL_ENVMAP_DEST_WIDTH); >;

/// 環境マップ展開用テクスチャのサンプラ。
sampler2D EnvDestTexSampler =
    sampler_state
    {
        Texture = <EnvDestTex>;
        MinFilter = POINT;
        MagFilter = POINT;
        MipFilter = POINT;
        AddressU = WRAP;
        AddressV = CLAMP;
    };

/// 環境BRDF項を事前計算した Look-up テクスチャ。
texture2D BrdfTex < string ResourceName = "texture/lookup_brdf.dds"; >;

/// 環境BRDF項を事前計算した Look-up テクスチャのサンプラ。
sampler BrdfTexSampler =
    sampler_state
    {
        Texture = <BrdfTex>;
        MinFilter = LINEAR;
        MagFilter = LINEAR;
        MipFilter = LINEAR;
        AddressU = CLAMP;
        AddressV = CLAMP;
    };

/// Hammersley のY座標を事前計算したテクスチャ。
texture2D HammersleyYTex < string ResourceName = "texture/hammersley_y.dds"; >;

/// Hammersley のY座標を事前計算したテクスチャのサンプラ。
sampler HammersleyYTexSampler =
    sampler_state
    {
        Texture = <HammersleyYTex>;
        MinFilter = POINT;
        MagFilter = POINT;
        MipFilter = POINT;
        AddressU = CLAMP;
        AddressV = CLAMP;
    };

/// ワールドビュープロジェクションマトリクス。
float4x4 WorldViewProjMatrix : WORLDVIEWPROJECTION;

/// スクリーン座標の W 値。
static float ScreenW = mul(float4(0, 0, 0, 1), WorldViewProjMatrix).w;

/// ビュープロジェクションマトリクス。
float4x4 ViewProjMatrix : VIEWPROJECTION;

/// カメラ位置。
float3 CameraPosition : POSITION < string Object = "Camera"; >;

/// ビューポートサイズ。
float2 ViewportSize : VIEWPORTPIXELSIZE;

/// ビューポートオフセット。
static float2 ViewportOffset = float2(0.5f, 0.5f) / ViewportSize;

/// 環境マップのカメラ位置。
float3 EnvCameraPosition : CONTROLOBJECT < string name = "(self)"; >;

/// 環境マップのビューポートオフセット。
static float2 EnvViewportOffset =
    {
        0.5f / (POSTIBL_ENVMAP_DEST_WIDTH),
        1.0f / (POSTIBL_ENVMAP_DEST_WIDTH),
    };

/// 環境マップの背景色。
#ifdef MIKUMIKUMOVING
float3 EnvBackColor : BACKGROUNDCOLOR;
#else // MIKUMIKUMOVING
float3 EnvBackColor = { 1, 1, 1 };
#endif // MIKUMIKUMOVING

/// SSRの適用度合い。
float SSRIntensity : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;

/// SSRのラフネスフェード終端値の基準値。
float SSRMaxRoughnessBase : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;

/// SSRのラフネスフェード終端値。デフォルトで 1 になる。
static float SSRMaxRoughness = max(SSRMaxRoughnessBase * 0.1f, 0.001f);

/// クリア色。
float4 ClearColor = { 0.6f, 0.6f, 0.6f, 0 };

/// クリア深度。
float ClearDepth = 1;

/// π値。
#define POSTIBL_PI 3.1415926536f

////////////////////
// 変数定義ここまで
////////////////////
// 関数定義ここから
////////////////////

/// @brief 環境マップをサンプリングする。
/// @param[in] ray サンプリングレイ方向。
/// @return サンプリング結果値。
float4 SampleEnvMap(float3 ray)
{
    float2 tuv =
        {
            atan2(ray.x, ray.z) / (POSTIBL_PI) * 0.5f + 0.5f,
            -atan2(ray.y, length(ray.xz)) / (POSTIBL_PI) + 0.5f,
        };

    return tex2D(EnvMapRTSampler, tuv);
}

/// @brief Look-up テクスチャから環境BRDF項を取得する。
/// @param[in] roughness ラフネス値。
/// @param[in] nvDot 法線ベクトルと視点ベクトルとの内積値。
/// @return 環境BRDF項。
float2 GetBrdf(float roughness, float nvDot)
{
    return tex2D(BrdfTexSampler, float2(nvDot, roughness)).rg;
}

/// @brief テクスチャを利用して Hammerslay 座標値を求める。
/// @param[in] index サンプリングインデックス値。
/// @param[in] sampleCount 総サンプリング数。
/// @return 座標値。
///
/// 参考文献: Hammersley Points on the Hemisphere
/// http://holger.dammertz.org/stuff/notes_HammersleyOnHemisphere.html
float2 CalcHammersley(uniform uint index, uniform uint sampleCount)
{
    float2 tex = { (index + 0.5f) / (POSTIBL_HAMMERSLEY_Y_SAMPLE_COUNT), 0.5f };
    return float2(float(index) / sampleCount, tex2D(HammersleyYTexSampler, tex).r);
}

/// @brief インポータンスサンプリング計算を行う。
/// @param[in] xi 座標値。
/// @param[in] r4 ラフネス値の4乗。
/// @param[in] normal 正規化済みの法線ベクトル値。
/// @return 計算結果のベクトル値。
///
/// 参考文献: SIGGRAPH 2013 Course: Physically Based Shading in Theory and Practice
/// http://blog.selfshadow.com/publications/s2013-shading-course/
float3 CalcImportanceSampleGGX(float2 xi, float r4, float3 normal)
{
    float phi = 2 * POSTIBL_PI * xi.x;
    float cosTheta = sqrt((1 - xi.y) / (1 + (r4 - 1) * xi.y));
    float sinTheta = sqrt(1 - cosTheta * cosTheta);

    float3 upVec = (abs(normal.y) < 0.999f) ? float3(0, 1, 0) : float3(0, 0, 1);
    float3 tanX = normalize(cross(upVec, normal));
    float3 tanY = cross(normal, tanX);

    return (
        (tanX * (sinTheta * cos(phi))) +
        (tanY * (sinTheta * sin(phi))) +
        (normal * cosTheta));
}

/// @brief SSRのレイトレースを行う。
/// @param[in] ray 単位レイベクトル。
/// @param[in] roughness ラフネス値。
/// @param[in] pos 位置。
/// @param[in] stepCount レイトレースステップ回数。
/// @param[in] stepOffset レイトレースステップのオフセット量。
/// @return トレース結果の色。α値は適用度合いを表す。
float4 TraceSSR(
    float3 ray,
    float roughness,
    float3 pos,
    uniform int stepCount,
    uniform float stepOffset)
{
    float4 result = { 1, 1, 1, 1 };

    // SSR適用度合いを設定
    result.a *= SSRIntensity;
    result.a *= saturate(2 * (1 - roughness / SSRMaxRoughness));
    if (result.a <= 0)
    {
        return result;
    }

    // スクリーン座標でのレイの始点と終点を算出
    float4 rayTemp = mul(float4(pos, 1), ViewProjMatrix);
    float3 ssRayBegin = rayTemp.xyz / rayTemp.w;
    rayTemp = mul(float4(pos + ray * ScreenW, 1), ViewProjMatrix);
    float3 ssRayEnd = rayTemp.xyz / rayTemp.w;

    // スクリーン座標でのレイの進行量を算出
    float3 ssRayStep = (ssRayEnd - ssRayBegin) / length(ssRayEnd.xy - ssRayBegin.xy);
    ssRayStep *= 1.5f;

    // 始点と進行量のUVz値を算出
    float3 uvzRayBegin = float3(ssRayBegin.xy * float2(0.5f, -0.5f) + 0.5f, ssRayBegin.z);
    float3 uvzRayStep = float3(ssRayStep.xy * float2(0.5f, -0.5f), ssRayStep.z);

    // パラメータ用意
    float step = 1.0f / (stepCount + 1);
    float compTolerance = abs(ssRayStep.z) * step * 2;
    float minHitTime = 1;
    float lastDiff = 0;
    float sampleTime = step * (stepOffset + 1);

    // ヒット判定
    for (int i = 0; i < stepCount; ++i, sampleTime += step)
    {
        // サンプル先UVz値決定
        float3 uvzSample = uvzRayBegin + uvzRayStep * sampleTime;

        // 深度値を取得
        float sampleDepth = tex2D(DepthSampler, uvzSample.xy).r;

        // 深度値の差分を算出
        float depthDiff = uvzSample.z - sampleDepth;

        // 判定
        if (abs(depthDiff + compTolerance) < compTolerance)
        {
            // ヒット位置記録
            float timeLerp = saturate(lastDiff / (lastDiff - depthDiff));
            float hitTime = sampleTime + timeLerp * step - step;
            minHitTime = min(minHitTime, hitTime);
        }

        // 深度値の差分を保存
        lastDiff = depthDiff;
    }

    // ヒット位置が遠い場合は適用度合いを弱める
    result.a *= saturate(4 * (1 - minHitTime));

    // ヒットUVz値決定
    float3 uvzHit = uvzRayBegin + uvzRayStep * minHitTime;

    // 画面端は適用度合いを弱める
    float2 ssHit = uvzHit.xy * float2(2, -2) + float2(-1, 1);
    float2 vig = saturate(abs(ssHit) * 5 - 4);
    result.a *= saturate(1 - dot(vig, vig));

    // 反射色を取得して乗算
    result *= tex2D(OrgColorRTSampler, uvzHit.xy);

    return result;
}

/// @brief SSR+IBL色をサンプリングする。
/// @param[in] roughness ラフネス値。
/// @param[in] pos 位置。
/// @param[in] normal 正規化済みの法線ベクトル値。
/// @param[in] eye 正規化済みの視点ベクトル値。
/// @param[in] sampleCount サンプリング回数。
/// @return サンプリング結果の色。
///
/// 参考文献: SIGGRAPH 2013 Course: Physically Based Shading in Theory and Practice
/// http://blog.selfshadow.com/publications/s2013-shading-course/
float3 SampleReflectionColor(
    float roughness,
    float3 pos,
    float3 normal,
    float3 eye,
    uniform uint sampleCount)
{
    float3 color = 0;
    float weight = 0;

    float r2 = roughness * roughness;
    float r4 = r2 * r2;

    for (uint i = 0; i < sampleCount; ++i)
    {
        float2 xi = CalcHammersley(i, sampleCount);
        float3 h = CalcImportanceSampleGGX(xi, r4, normal);
        float3 ray = normalize(2 * dot(eye, h) * h - eye);

        float nrayDot = saturate(dot(normal, ray));
        if (nrayDot > 0)
        {
            // SSR色取得
            float4 c =
                TraceSSR(
                    ray,
                    roughness,
                    pos,
                    (POSTIBL_SSR_STEP_COUNT),
                    (POSTIBL_SSR_STEP_OFFSET));

            if (c.a < 1)
            {
                // 環境マップ色とブレンド
                c.rgb *= c.a;
                c.rgb += SampleEnvMap(ray).rgb * (1 - c.a);
            }

            // 重み付け加算
            color.rgb += c.rgb * nrayDot;
            weight += nrayDot;
        }
    }

    return (color / max(weight, 0.001f));
}

/// @brief SSR+IBL計算を行う。
/// @param[in] specular スペキュラ色。
/// @param[in] roughness ラフネス値。
/// @param[in] tex スクリーンスペースのUV値。
/// @return 計算結果の色。
float3 CalcReflectionColor(float3 specular, float roughness, float2 tex)
{
    // 位置と法線を取得
    float3 pos = tex2D(PositionSampler, tex).xyz;
    float3 normal = normalize(tex2D(NormalSampler, tex).xyz);

    // 単位視点ベクトルを算出
    float3 eye = normalize(CameraPosition - pos);

    // SSR+IBL色をサンプリング
    float3 color =
        SampleReflectionColor(
            roughness,
            pos,
            normal,
            eye,
            (POSTIBL_REFLECTION_SAMPLE_COUNT));

    // BRDF項を取得
    float2 brdf = GetBrdf(roughness, saturate(dot(normal, eye)));

    // BRDFを乗算
    color.rgb *= specular.rgb * brdf.x + brdf.y;

    return color;
}

////////////////////
// 関数定義ここから
////////////////////
// シェーダ処理ここから
////////////////////

/// 頂点シェーダの出力構造体。
struct VSOutput
{
    float4 pos : POSITION;  ///< 位置。
    float2 tex : TEXCOORD0; ///< テクスチャUV。
};

/// 環境マップ展開の頂点シェーダ処理を行う。
VSOutput RunEnvMapVS(float4 pos : POSITION, float2 tex : TEXCOORD0)
{
    VSOutput vsOut = (VSOutput)0;

    vsOut.pos = pos;
    vsOut.tex = tex + EnvViewportOffset;

    return vsOut;
}

/// 環境マップ展開のピクセルシェーダ処理を行う。
float4 RunEnvMapPS(float2 tex : TEXCOORD0) : COLOR
{
    // 環境マップ上のUV値を取得
    float2 uv = tex2D(EnvDestTexSampler, tex).rg;

    // 色を取得
    float4 color = tex2D(EnvColorSampler, uv);

    // 色を背景色と混ぜる
    color.rgb = color.rgb * color.a + EnvBackColor.rgb * (1 - color.a);

    /// @todo 深度値を取得してαに設定
    color.a = 1;

    return color;
}

/// 最終レンダリングの頂点シェーダ処理を行う。
VSOutput RunPostIBLVS(float4 pos : POSITION, float2 tex : TEXCOORD0)
{
    VSOutput vsOut = (VSOutput)0;

    vsOut.pos = pos;
    vsOut.tex = tex + ViewportOffset;

    return vsOut;
}

/// 最終レンダリングのピクセルシェーダ処理を行う。
float4 RunPostIBLPS(float2 tex : TEXCOORD0) : COLOR
{
#if 0
    // 環境マップを表示してみる。
    return tex2D(EnvColorSampler, tex);
#endif

    // 元の色を取得
    float4 orgColor = tex2D(OrgColorRTSampler, tex);

    // 物理ベースマテリアル値を取得
    float4 pbm = tex2D(MaterialSampler, tex);
    if (pbm.a <= 0)
    {
        // 反映度合いが 0 ならば元の色を返す
        return orgColor;
    }
    float metal = pbm.x;
    float rough = pbm.y;
    float specular = pbm.z;

    // アルベドを取得
    float4 albedo = tex2D(AlbedoSampler, tex);

    // ディフューズ色とスペキュラ色を算出
    float3 color = albedo.xyz * (1 - metal);
    float3 specColor = lerp(specular.xxx, albedo.xyz, metal);

    // SSR+IBL結果を加算
    color += CalcReflectionColor(specColor, rough, tex);

    // 元の色とアルベドとの差を元に補正
    // 元の色 < アルベド : 影で暗くなっている → 減衰割合を乗算
    // 元の色 > アルベド : エフェクト等で発光 → 増加量を加算
    color.r = (orgColor.r < albedo.r) ? (color.r * orgColor.r / albedo.r) : (color.r + orgColor.r - albedo.r);
    color.g = (orgColor.g < albedo.g) ? (color.g * orgColor.g / albedo.g) : (color.g + orgColor.g - albedo.g);
    color.b = (orgColor.b < albedo.b) ? (color.b * orgColor.b / albedo.b) : (color.b + orgColor.b - albedo.b);

    // 反映度合いを適用
    color.rgb = lerp(orgColor.rgb, color.rgb, pbm.a);

    return float4(color, orgColor.a);
}

/// テクニック定義。
technique PostIBLTec <
    string Script =
        // 通常描画結果を保存
        "RenderColorTarget0=OrgColorRT;"
        "RenderDepthStencilTarget=OrgColorDS;"
        "ClearSetColor=ClearColor;"
        "ClearSetDepth=ClearDepth;"
        "Clear=Color;"
        "Clear=Depth;"
        "ScriptExternal=Color;"

        // 環境マップを展開
        "RenderColorTarget0=EnvMapRT;"
        "Pass=EnvMapPass;"

        // 最終レンダリング
        "RenderColorTarget0=;"
        "RenderDepthStencilTarget=;"
        "Pass=PostIBLPass;"; >
{
    pass EnvMapPass < string Script= "Draw=Buffer;"; >
    {
        AlphaBlendEnable = false;
        AlphaTestEnable = false;
        ZEnable = false;
        ZWriteEnable = false;
        VertexShader = compile vs_3_0 RunEnvMapVS();
        PixelShader = compile ps_3_0 RunEnvMapPS();
    }

    pass PostIBLPass < string Script= "Draw=Buffer;"; >
    {
        ZEnable = false;
        VertexShader = compile vs_3_0 RunPostIBLVS();
        PixelShader = compile ps_3_0 RunPostIBLPS();
    }
}

////////////////////
// シェーダ処理ここまで
////////////////////
