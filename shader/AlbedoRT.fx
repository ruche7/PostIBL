/// @file
/// @brief オフスクリーンにアルベド値を書き出すためのエフェクト。
/// @author ルーチェ

////////////////////
// 変数定義ここから
////////////////////

/// ワールドビュープロジェクションマトリクス。
float4x4 WorldViewProjMatrix : WORLDVIEWPROJECTION;

/// ワールドビューマトリクス。
float4x4 WorldViewMatrix : WORLDVIEW;

#ifdef MIKUMIKUMOVING

/// ワールドマトリクス。
float4x4 WorldMatrix : WORLD;

/// プロジェクションマトリクス。
float4x4 ProjMatrix : PROJECTION;

/// ワールド空間上のカメラ位置。
float3 CameraPosition : POSITION < string Object = "Camera"; >;

#else // MIKUMIKUMOVING

/// サブテクスチャ使用フラグ。
bool use_subtexture;

#endif // MIKUMIKUMOVING

// マテリアル色
float4 MaterialDiffuse : DIFFUSE < string Object = "Geometry"; >;
float3 MaterialAmbient : AMBIENT < string Object = "Geometry"; >;
float3 MaterialEmmisive : EMISSIVE < string Object = "Geometry"; >;

// ライト色
float3 LightDiffuse : DIFFUSE < string Object = "Light"; >;
float3 LightAmbient : AMBIENT < string Object = "Light"; >;

// 合算色
static float4 DiffuseColor = MaterialDiffuse * float4(LightDiffuse, 1);
static float3 AmbientColor = MaterialAmbient * LightAmbient + MaterialEmmisive;

// テクスチャ材質モーフ
float4 TextureAddValue : ADDINGTEXTURE;
float4 TextureMulValue : MULTIPLYINGTEXTURE;
float4 SphereAddValue : ADDINGSPHERETEXTURE;
float4 SphereMulValue : MULTIPLYINGSPHERETEXTURE;

/// スフィアマップ加算合成フラグ。
bool spadd;

/// オブジェクトテクスチャ。
texture ObjectTex : MATERIALTEXTURE;

/// オブジェクトテクスチャのサンプラ。
sampler ObjectTexSampler =
    sampler_state
    {
        Texture = <ObjectTex>;
        MinFilter = LINEAR;
        MagFilter = LINEAR;
        MipFilter = LINEAR;
        AddressU = WRAP;
        AddressV = WRAP;
    };

/// スフィアマップテクスチャ。
texture SphereTex : MATERIALSPHEREMAP;

/// スフィアマップテクスチャのサンプラ。
sampler SphereTexSampler =
    sampler_state
    {
        Texture = <SphereTex>;
        MinFilter = LINEAR;
        MagFilter = LINEAR;
        MipFilter = LINEAR;
        AddressU = WRAP;
        AddressV = WRAP;
    };

////////////////////
// 変数定義ここまで
////////////////////
// シェーダ処理ここから
////////////////////

/// 頂点シェーダの出力構造体。
struct VSOutput
{
    float4 pos : POSITION;      ///< 位置。
    float2 tex : TEXCOORD0;     ///< テクスチャ座標。
    float2 spTex : TEXCOORD1;   ///< スフィアマップテクスチャ座標。
    float4 color : COLOR0;      ///< カラー値。
};

/// 頂点シェーダ処理を行う。
#ifdef MIKUMIKUMOVING
VSOutput RunVS(
    MMM_SKINNING_INPUT mmmIn,
    uniform bool useTexture,
    uniform bool useSphereMap,
    uniform bool useToon)
#else // MIKUMIKUMOVING
VSOutput RunVS(
    float4 pos : POSITION,
    float3 normal : NORMAL,
    float2 tex : TEXCOORD0,
    float2 subTex : TEXCOORD1,
    uniform bool useTexture,
    uniform bool useSphereMap,
    uniform bool useToon)
#endif // MIKUMIKUMOVING
{
    VSOutput vsOut = (VSOutput)0;

#ifdef MIKUMIKUMOVING
    MMM_SKINNING_OUTPUT skinOut =
        MMM_SkinnedPositionNormal(
            mmmIn.Pos,
            mmmIn.Normal,
            mmmIn.BlendWeight,
            mmmIn.BlendIndices,
            mmmIn.SdefC,
            mmmIn.SdefR0,
            mmmIn.SdefR1);
    float4 pos = skinOut.Position;
    float3 normal = skinOut.Normal;
    float2 tex = mmmIn.Tex;
#endif // MIKUMIKUMOVING

    // 位置
    float4x4 wvp = WorldViewProjMatrix;
#ifdef MIKUMIKUMOVING
    if (MMM_IsDinamicProjection)
    {
        float3 eye = CameraPosition -  mul(pos, WorldMatrix).xyz;
        wvp = mul(WorldViewMatrix, MMM_DynamicFov(ProjMatrix, length(eye)));
    }
#endif // MIKUMIKUMOVING
    vsOut.pos = mul(pos, wvp);

    // テクスチャ座標
    vsOut.tex = tex;

    // スフィアマップテクスチャ座標
    if (useSphereMap)
    {
#ifndef MIKUMIKUMOVING
        if (use_subtexture)
        {
            vsOut.spTex = subTex;
        }
        else
#endif // MIKUMIKUMOVING
        {
            float3 wvNormal = mul(normal, (float3x3)WorldViewMatrix);
            vsOut.spTex.x = wvNormal.x * 0.5f + 0.5f;
            vsOut.spTex.y = wvNormal.y * -0.5f + 0.5f;
        }
    }

    // カラー値
    vsOut.color = DiffuseColor;
#ifndef MIKUMIKUMOVING
    if (useToon)
    {
        vsOut.color.rgb = float3(0, 0, 0);
    }
#endif // MIKUMIKUMOVING
    vsOut.color.rgb += AmbientColor.rgb;
    vsOut.color = saturate(vsOut.color);

    return vsOut;
}

/// ピクセルシェーダ処理を行う。
float4 RunPS(
    VSOutput psIn,
    uniform bool useTexture,
    uniform bool useSphereMap,
    uniform bool useToon) : COLOR
{
    float4 color = psIn.color;

    // テクスチャ適用
    if (useTexture)
    {
        float4 texColor = tex2D(ObjectTexSampler, psIn.tex);

        texColor.rgb = texColor.rgb * TextureMulValue.rgb + TextureAddValue.rgb;
        float texRate = TextureMulValue.a + TextureAddValue.a;

        color.rgb *= lerp(float3(1, 1, 1), texColor.rgb, texRate);
        color.a *= texColor.a;
    }

    // スフィアマップ適用
    if (useSphereMap)
    {
        float4 spColor = tex2D(SphereTexSampler, psIn.spTex);

        spColor.rgb = spColor.rgb * SphereMulValue.rgb + SphereAddValue.rgb;
        float spRate = SphereMulValue.a + SphereAddValue.a;

        if (spadd)
        {
            color.rgb += lerp(float3(0, 0, 0), spColor.rgb, spRate);
        }
        else
        {
            color.rgb *= lerp(float3(1, 1, 1), spColor.rgb, spRate);
        }
        color.a *= spColor.a;
    }

    return color;
}

/// オブジェクト描画テクニック定義用マクロ。
#define POSTIBL_OBJECT_TEC_DEF(mmdp,use_tex,use_sph,use_toon) \
    technique ObjectTec_##mmdp##use_tex##use_sph##use_toon < \
        string MMDPass = #mmdp; \
        bool UseTexture = use_tex; \
        bool UseSphereMap = use_sph; \
        bool UseToon = use_toon; > \
    { \
        pass ObjectPass \
        { \
            VertexShader = compile vs_3_0 RunVS(use_tex, use_sph, use_toon); \
            PixelShader = compile ps_3_0 RunPS(use_tex, use_sph, use_toon); } }

// オブジェクト描画テクニック群定義
POSTIBL_OBJECT_TEC_DEF(object,    false, false, false)
POSTIBL_OBJECT_TEC_DEF(object,     true, false, false)
POSTIBL_OBJECT_TEC_DEF(object,    false,  true, false)
POSTIBL_OBJECT_TEC_DEF(object,     true,  true, false)
POSTIBL_OBJECT_TEC_DEF(object,    false, false,  true)
POSTIBL_OBJECT_TEC_DEF(object,     true, false,  true)
POSTIBL_OBJECT_TEC_DEF(object,    false,  true,  true)
POSTIBL_OBJECT_TEC_DEF(object,     true,  true,  true)
POSTIBL_OBJECT_TEC_DEF(object_ss, false, false, false)
POSTIBL_OBJECT_TEC_DEF(object_ss,  true, false, false)
POSTIBL_OBJECT_TEC_DEF(object_ss, false,  true, false)
POSTIBL_OBJECT_TEC_DEF(object_ss,  true,  true, false)
POSTIBL_OBJECT_TEC_DEF(object_ss, false, false,  true)
POSTIBL_OBJECT_TEC_DEF(object_ss,  true, false,  true)
POSTIBL_OBJECT_TEC_DEF(object_ss, false,  true,  true)
POSTIBL_OBJECT_TEC_DEF(object_ss,  true,  true,  true)

// 輪郭等は描画しない
technique EdgeTec < string MMDPass = "edge"; > { }
technique ShadowTec < string MMDPass = "shadow"; > { }
technique ZPlotTec < string MMDPass = "zplot"; > { }

////////////////////
// シェーダ処理ここまで
////////////////////
