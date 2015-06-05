/// @file
/// @brief オフスクリーンに環境カラーマップを書き出すためのエフェクト。
/// @author ルーチェ
///
/// MikuMikuMoving 用。

#include "EnvMapRTCommon.fxsub"

// 以下は SampleBase.fxm をコピペしてコード変更したもの。
// 変更箇所は #if 〜 #endif で括られている。
////////////////////////////////////////////////////////////////////////////////////////////////
//
//  MikuMikuMoving用サンプルシェーダ
//  2013/05/01
//
////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

#if 0

//座標変換行列
float4x4 WorldViewProjMatrix	: WORLDVIEWPROJECTION;
float4x4 WorldMatrix		: WORLD;
float4x4 ViewMatrix		: VIEW;
float4x4 ProjMatrix		: PROJECTION;

#endif // 0

//ライト関連
bool	 LightEnables[MMM_LightCount]		: LIGHTENABLES;		// 有効フラグ
float4x4 LightWVPMatrices[MMM_LightCount]	: LIGHTWVPMATRICES;	// 座標変換行列
float3   LightDirection[MMM_LightCount]		: LIGHTDIRECTIONS;	// 方向
float3   LightPositions[MMM_LightCount]		: LIGHTPOSITIONS;	// ライト位置
float    LightZFars[MMM_LightCount]			: LIGHTZFARS;		// ライトzFar値

//材質モーフ関連
float4	 AddingTexture		  : ADDINGTEXTURE;	// 材質モーフ加算Texture値
float4	 AddingSphere		  : ADDINGSPHERE;	// 材質モーフ加算SphereTexture値
float4	 MultiplyTexture	  : MULTIPLYINGTEXTURE;	// 材質モーフ乗算Texture値
float4	 MultiplySphere		  : MULTIPLYINGSPHERE;	// 材質モーフ乗算SphereTexture値

#if 0

//カメラ位置
float3	 CameraPosition		: POSITION  < string Object = "Camera"; >;

#endif // 0

// マテリアル色
float4   MaterialDiffuse	: DIFFUSE  < string Object = "Geometry"; >;
float3   MaterialAmbient	: AMBIENT  < string Object = "Geometry"; >;
float3   MaterialEmmisive	: EMISSIVE < string Object = "Geometry"; >;
float3   MaterialSpecular	: SPECULAR < string Object = "Geometry"; >;
float    SpecularPower		: SPECULARPOWER < string Object = "Geometry"; >;
float4   MaterialToon		: TOONCOLOR;
float4   EdgeColor			: EDGECOLOR;
float    EdgeWidth			: EDGEWIDTH;
float4   GroundShadowColor	: GROUNDSHADOWCOLOR;

bool	 spadd;    			// スフィアマップ加算合成フラグ
bool     usetoontexturemap;	// Toonテクスチャフラグ

// ライト色
float3   LightDiffuses[MMM_LightCount]      : LIGHTDIFFUSECOLORS;
float3   LightAmbients[MMM_LightCount]      : LIGHTAMBIENTCOLORS;
float3   LightSpeculars[MMM_LightCount]     : LIGHTSPECULARCOLORS;

// ライト色
static float4 DiffuseColor[3]  = { MaterialDiffuse * float4(LightDiffuses[0], 1.0f)
				 , MaterialDiffuse * float4(LightDiffuses[1], 1.0f)
				 , MaterialDiffuse * float4(LightDiffuses[2], 1.0f)};
static float3 AmbientColor[3]  = { saturate(MaterialAmbient * LightAmbients[0]) + MaterialEmmisive
				 , saturate(MaterialAmbient * LightAmbients[1]) + MaterialEmmisive
				 , saturate(MaterialAmbient * LightAmbients[2]) + MaterialEmmisive};
static float3 SpecularColor[3] = { MaterialSpecular * LightSpeculars[0]
				 , MaterialSpecular * LightSpeculars[1]
				 , MaterialSpecular * LightSpeculars[2]};

// オブジェクトのテクスチャ
texture ObjectTexture: MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state {
	texture = <ObjectTexture>;
	MINFILTER = LINEAR;
	MAGFILTER = LINEAR;
#if 1
    AddressU = CLAMP;
    AddressV = CLAMP;
#endif
};

// スフィアマップのテクスチャ
texture ObjectSphereMap: MATERIALSPHEREMAP;
sampler ObjSphareSampler = sampler_state {
	texture = <ObjectSphereMap>;
	MINFILTER = LINEAR;
	MAGFILTER = LINEAR;
#if 1
    AddressU = CLAMP;
    AddressV = CLAMP;
#endif
};

///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画
struct VS_OUTPUT {
	float4 Pos		: POSITION;		// 射影変換座標
	float2 Tex		: TEXCOORD0;	// テクスチャ
	float4 SubTex	: TEXCOORD1;	// サブテクスチャ/スフィアマップテクスチャ座標
	float3 Normal	: TEXCOORD2;	// 法線
	float3 Eye		: TEXCOORD3;	// カメラとの相対位置
	float4 SS_UV1   : TEXCOORD4;	// セルフシャドウテクスチャ座標
	float4 SS_UV2   : TEXCOORD5;	// セルフシャドウテクスチャ座標
	float4 SS_UV3   : TEXCOORD6;	// セルフシャドウテクスチャ座標
	float4 Color	: COLOR0;		// ライト0による色
};

//==============================================
// 頂点シェーダ
// MikuMikuMoving独自の頂点シェーダ入力(MMM_SKINNING_INPUT)
//==============================================
#if 1
VS_OUTPUT Object_VS(MMM_SKINNING_INPUT IN, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon, uniform bool useSelfShadow, uniform int face)
#else
VS_OUTPUT Basic_VS(MMM_SKINNING_INPUT IN, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon, uniform bool useSelfShadow)
#endif
{
#if 1
    float4x4 ViewMatrix = EnvMapFaceViewMatrices[face];
#endif

	VS_OUTPUT Out = (VS_OUTPUT)0;

	//================================================================================
	//MikuMikuMoving独自のスキニング関数(MMM_SkinnedPositionNormal)。座標と法線を取得する。
	//================================================================================
	MMM_SKINNING_OUTPUT SkinOut = MMM_SkinnedPositionNormal(IN.Pos, IN.Normal, IN.BlendWeight, IN.BlendIndices, IN.SdefC, IN.SdefR0, IN.SdefR1);

	// カメラとの相対位置
	Out.Eye = CameraPosition - mul( SkinOut.Position, WorldMatrix ).xyz;
	// 頂点法線
	Out.Normal = normalize( mul( SkinOut.Normal, (float3x3)WorldMatrix ) );

	// 頂点座標
	if (MMM_IsDinamicProjection)
	{
		float4x4 wvpmat = mul(mul(WorldMatrix, ViewMatrix), MMM_DynamicFov(ProjMatrix, length(Out.Eye)));
		Out.Pos = mul( SkinOut.Position, wvpmat );
	}
	else
	{
#if 1
        float4x4 WorldViewProjMatrix = EnvMapFaceWVPMatrices[face];
#endif
		Out.Pos = mul( SkinOut.Position, WorldViewProjMatrix );
	}

	// ディフューズ色＋アンビエント色 計算
	float3 color = float3(0, 0, 0);
	float3 ambient = float3(0, 0, 0);
	float count = 0;
	for (int i = 0; i < 3; i++) {
		if (LightEnables[i]) {
			color += (float3(1,1,1) - color) * (max(0, DiffuseColor[i] * dot(Out.Normal, -LightDirection[i])));
			ambient += AmbientColor[i];
			count = count + 1.0;
		}
	}
	Out.Color.rgb = saturate(ambient / count + color);
	Out.Color.a = MaterialDiffuse.a;

	// テクスチャ座標
	Out.Tex = IN.Tex;
	Out.SubTex.xy = IN.AddUV1.xy;

	if ( useSphereMap ) {
		// スフィアマップテクスチャ座標
		float2 NormalWV = mul( Out.Normal, (float3x3)ViewMatrix );
		Out.SubTex.z = NormalWV.x * 0.5f + 0.5f;
		Out.SubTex.w = NormalWV.y * -0.5f + 0.5f;
	}
    
	if (useSelfShadow) {
		float4 dpos = mul(SkinOut.Position, WorldMatrix);
		//デプスマップテクスチャ座標
		Out.SS_UV1 = mul(dpos, LightWVPMatrices[0]);
		Out.SS_UV2 = mul(dpos, LightWVPMatrices[1]);
		Out.SS_UV3 = mul(dpos, LightWVPMatrices[2]);
		
		Out.SS_UV1.y = -Out.SS_UV1.y;
		Out.SS_UV2.y = -Out.SS_UV2.y;
		Out.SS_UV3.y = -Out.SS_UV3.y;

		Out.SS_UV1.z = (length(LightPositions[0] - SkinOut.Position) / LightZFars[0]);
		Out.SS_UV2.z = (length(LightPositions[1] - SkinOut.Position) / LightZFars[1]);
		Out.SS_UV3.z = (length(LightPositions[2] - SkinOut.Position) / LightZFars[2]);
	}

#if 1
    Out.Pos = CalcEnvMapFacePosition(Out.Pos, face);
#endif

	return Out;
}

//==============================================
// ピクセルシェーダ
// 入力は特に独自形式なし
//==============================================
#if 1
float4 Object_PS(VS_OUTPUT IN, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon, uniform bool useSelfShadow, uniform int face) : COLOR0
#else
float4 Basic_PS(VS_OUTPUT IN, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon, uniform bool useSelfShadow) : COLOR0
#endif
{
#if 1
    ClipEnvMapFace(IN.Eye, face);
#endif

	float4 Color = IN.Color;
	float4 texColor = float4(1,1,1,1);
	float  texAlpha = MultiplyTexture.a + AddingTexture.a;

	//スペキュラ色計算
	float3 HalfVector;
	float3 Specular = 0;
	for (int i = 0; i < 3; i++) {
		if (LightEnables[i]) {
			HalfVector = normalize( normalize(IN.Eye) + -LightDirection[i] );
			Specular += pow( max(0,dot( HalfVector, normalize(IN.Normal) )), SpecularPower ) * SpecularColor[i];
		}
	}

	// テクスチャ適用
	if (useTexture) {
		texColor = tex2D(ObjTexSampler, IN.Tex);
		texColor.rgb = (texColor.rgb * MultiplyTexture.rgb + AddingTexture.rgb) * texAlpha + (1.0 - texAlpha);
	}
	Color.rgb *= texColor.rgb;

	// スフィアマップ適用
	if ( useSphereMap ) {
		// スフィアマップ適用
		if(spadd) Color.rgb = Color.rgb + (tex2D(ObjSphareSampler,IN.SubTex.zw).rgb * MultiplySphere.rgb + AddingSphere.rgb);
		else      Color.rgb = Color.rgb * (tex2D(ObjSphareSampler,IN.SubTex.zw).rgb * MultiplySphere.rgb + AddingSphere.rgb);
	}
	// アルファ適用
	Color.a = IN.Color.a * texColor.a;

	// セルフシャドウなしのトゥーン適用
	float3 color;
	if (!useSelfShadow && useToon && usetoontexturemap ) {
		//================================================================================
		// MikuMikuMovingデフォルトのトゥーン色を取得する(MMM_GetToonColor)
		//================================================================================
		color = MMM_GetToonColor(MaterialToon, IN.Normal, LightDirection[0], LightDirection[1], LightDirection[2]);
		Color.rgb *= color;
	}
	// セルフシャドウ
	if (useSelfShadow) {

		if (useToon && usetoontexturemap) {
			//================================================================================
			// MikuMikuMovingデフォルトのセルフシャドウ色を取得する(MMM_GetSelfShadowToonColor)
			//================================================================================
			float3 shadow = MMM_GetToonColor(MaterialToon, IN.Normal, LightDirection[0], LightDirection[1], LightDirection[2]);
			color = MMM_GetSelfShadowToonColor(MaterialToon, IN.Normal, IN.SS_UV1, IN.SS_UV2, IN.SS_UV3, false, useToon);

			Color.rgb *= min(shadow, color);
		}
		else {
			Color.rgb *= MMM_GetSelfShadowToonColor(MaterialToon, IN.Normal, IN.SS_UV1, IN.SS_UV2, IN.SS_UV3, false, useToon);
		}
	}

	// スペキュラ適用
	Color.rgb += Specular;

    return Color;
}

//==============================================
// オブジェクト描画テクニック
// UseSelfShadowが独自に追加されています。
//==============================================
#if 1

POSTIBL_OBJECT_TEC_DEF(false, false, false)
POSTIBL_OBJECT_TEC_DEF(true , false, false)
POSTIBL_OBJECT_TEC_DEF(false, true , false)
POSTIBL_OBJECT_TEC_DEF(true , true , false)
POSTIBL_OBJECT_TEC_DEF(false, false, true )
POSTIBL_OBJECT_TEC_DEF(true , false, true )
POSTIBL_OBJECT_TEC_DEF(false, true , true )
POSTIBL_OBJECT_TEC_DEF(true , true , true )
POSTIBL_OBJECT_SS_TEC_DEF(false, false, false)
POSTIBL_OBJECT_SS_TEC_DEF(true , false, false)
POSTIBL_OBJECT_SS_TEC_DEF(false, true , false)
POSTIBL_OBJECT_SS_TEC_DEF(true , true , false)
POSTIBL_OBJECT_SS_TEC_DEF(false, false, true )
POSTIBL_OBJECT_SS_TEC_DEF(true , false, true )
POSTIBL_OBJECT_SS_TEC_DEF(false, true , true )
POSTIBL_OBJECT_SS_TEC_DEF(true , true , true )

#else
technique MainTec0 < string MMDPass = "object"; bool UseTexture = false; bool UseSphereMap = false; bool UseToon = false; bool UseSelfShadow = false; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 Basic_VS(false, false, false, false);
        PixelShader  = compile ps_3_0 Basic_PS(false, false, false, false);
    }
}

technique MainTec1 < string MMDPass = "object"; bool UseTexture = true; bool UseSphereMap = false; bool UseToon = false; bool UseSelfShadow = false; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 Basic_VS(true, false, false, false);
        PixelShader  = compile ps_3_0 Basic_PS(true, false, false, false);
    }
}

technique MainTec2 < string MMDPass = "object"; bool UseTexture = false; bool UseSphereMap = true; bool UseToon = false; bool UseSelfShadow = false; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 Basic_VS(false, true, false, false);
        PixelShader  = compile ps_3_0 Basic_PS(false, true, false, false);
    }
}

technique MainTec3 < string MMDPass = "object"; bool UseTexture = true; bool UseSphereMap = true; bool UseToon = false; bool UseSelfShadow = false; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 Basic_VS(true, true, false, false);
        PixelShader  = compile ps_3_0 Basic_PS(true, true, false, false);
    }
}

technique MainTec4 < string MMDPass = "object"; bool UseTexture = false; bool UseSphereMap = false; bool UseToon = true; bool UseSelfShadow = false; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 Basic_VS(false, false, true, false);
        PixelShader  = compile ps_3_0 Basic_PS(false, false, true, false);
    }
}

technique MainTec5 < string MMDPass = "object"; bool UseTexture = true; bool UseSphereMap = false; bool UseToon = true; bool UseSelfShadow = false; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 Basic_VS(true, false, true, false);
        PixelShader  = compile ps_3_0 Basic_PS(true, false, true, false);
    }
}

technique MainTec6 < string MMDPass = "object"; bool UseTexture = false; bool UseSphereMap = true; bool UseToon = true; bool UseSelfShadow = false; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 Basic_VS(false, true, true, false);
        PixelShader  = compile ps_3_0 Basic_PS(false, true, true, false);
    }
}

technique MainTec7 < string MMDPass = "object"; bool UseTexture = true; bool UseSphereMap = true; bool UseToon = true; bool UseSelfShadow = false; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 Basic_VS(true, true, true, false);
        PixelShader  = compile ps_3_0 Basic_PS(true, true, true, false);
    }
}
technique MainTec8 < string MMDPass = "object"; bool UseTexture = false; bool UseSphereMap = false; bool UseToon = false; bool UseSelfShadow = true; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 Basic_VS(false, false, false, true);
        PixelShader  = compile ps_3_0 Basic_PS(false, false, false, true);
    }
}

technique MainTec9 < string MMDPass = "object"; bool UseTexture = true; bool UseSphereMap = false; bool UseToon = false; bool UseSelfShadow = true; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 Basic_VS(true, false, false, true);
        PixelShader  = compile ps_3_0 Basic_PS(true, false, false, true);
    }
}

technique MainTec10 < string MMDPass = "object"; bool UseTexture = false; bool UseSphereMap = true; bool UseToon = false; bool UseSelfShadow = true; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 Basic_VS(false, true, false, true);
        PixelShader  = compile ps_3_0 Basic_PS(false, true, false, true);
    }
}

technique MainTec11 < string MMDPass = "object"; bool UseTexture = true; bool UseSphereMap = true; bool UseToon = false; bool UseSelfShadow = true; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 Basic_VS(true, true, false, true);
        PixelShader  = compile ps_3_0 Basic_PS(true, true, false, true);
    }
}

technique MainTec12 < string MMDPass = "object"; bool UseTexture = false; bool UseSphereMap = false; bool UseToon = true; bool UseSelfShadow = true; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 Basic_VS(false, false, true, true);
        PixelShader  = compile ps_3_0 Basic_PS(false, false, true, true);
    }
}

technique MainTec13 < string MMDPass = "object"; bool UseTexture = true; bool UseSphereMap = false; bool UseToon = true; bool UseSelfShadow = true; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 Basic_VS(true, false, true, true);
        PixelShader  = compile ps_3_0 Basic_PS(true, false, true, true);
    }
}

technique MainTec14 < string MMDPass = "object"; bool UseTexture = false; bool UseSphereMap = true; bool UseToon = true; bool UseSelfShadow = true; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 Basic_VS(false, true, true, true);
        PixelShader  = compile ps_3_0 Basic_PS(false, true, true, true);
    }
}

technique MainTec15 < string MMDPass = "object"; bool UseTexture = true; bool UseSphereMap = true; bool UseToon = true; bool UseSelfShadow = true; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 Basic_VS(true, true, true, true);
        PixelShader  = compile ps_3_0 Basic_PS(true, true, true, true);
    }
}
#endif

////////////////////////////////////////////////////////////////////////////////////////////////
// 輪郭描画

//==============================================
// 頂点シェーダ
//==============================================
#if 1
EdgeShadowVSOutput Edge_VS(MMM_SKINNING_INPUT IN, uniform int face)
#else
float4 Edge_VS(MMM_SKINNING_INPUT IN) : POSITION 
#endif
{
#if 1
    EdgeShadowVSOutput Out = (EdgeShadowVSOutput)0;
    float4x4 ViewMatrix = EnvMapFaceViewMatrices[face];
#endif

	//================================================================================
	//MikuMikuMoving独自のスキニング関数(MMM_SkinnedPosition)。座標を取得する。
	//================================================================================
	MMM_SKINNING_OUTPUT SkinOut = MMM_SkinnedPositionNormal(IN.Pos, IN.Normal, IN.BlendWeight, IN.BlendIndices, IN.SdefC, IN.SdefR0, IN.SdefR1);

	float4 position = SkinOut.Position;

	// 頂点座標
	if (MMM_IsDinamicProjection)
	{
		float dist = length(CameraPosition - mul( position, WorldMatrix ));
		float4x4 wvpmat = mul(mul(WorldMatrix, ViewMatrix), MMM_DynamicFov(ProjMatrix, dist));

		position = position + float4(SkinOut.Normal, 0) * IN.EdgeWeight * EdgeWidth * distance(SkinOut.Position.xyz, CameraPosition) * MMM_GetDynamicFovEdgeRate(dist);
#if 1
        Out.pos = mul( position, wvpmat );
#else
		return mul( position, wvpmat );
#endif
	}
	else
	{
		position = position + float4(SkinOut.Normal, 0) * IN.EdgeWeight * EdgeWidth * distance(SkinOut.Position.xyz, CameraPosition);
#if 1
        float4x4 WorldViewProjMatrix = EnvMapFaceWVPMatrices[face];
        Out.pos = mul( position, WorldViewProjMatrix );
#else
		return mul( position, WorldViewProjMatrix );
#endif
	}

#if 1
    Out.pos = CalcEnvMapFacePosition(Out.pos, face);
    Out.eye = CameraPosition - mul(position, WorldMatrix).xyz;
    return Out;
#endif
}

//==============================================
// ピクセルシェーダ
//==============================================
#if 1
float4 Edge_PS(EdgeShadowVSOutput IN, uniform int face) : COLOR
#else
float4 Edge_PS() : COLOR
#endif
{
#if 1
    clip(EdgeWidth - 0.000001f);
    ClipEnvMapFace(IN.eye, face);
#endif

	// 輪郭色で塗りつぶし
	return EdgeColor;
}

//==============================================
// 輪郭描画テクニック
//==============================================
#if 1

POSTIBL_EDGE_TEC_DEF

#else
technique EdgeTec < string MMDPass = "edge"; > {
	pass DrawEdge {
		AlphaBlendEnable = FALSE;
		AlphaTestEnable  = FALSE;

		VertexShader = compile vs_2_0 Edge_VS();
		PixelShader  = compile ps_2_0 Edge_PS();
	}
}
#endif

///////////////////////////////////////////////////////////////////////////////////////////////
// 影（非セルフシャドウ）描画

//==============================================
// 頂点シェーダ
//==============================================
#if 1
EdgeShadowVSOutput Shadow_VS(MMM_SKINNING_INPUT IN, uniform int face)
#else
float4 Shadow_VS(MMM_SKINNING_INPUT IN) : POSITION
#endif
{
#if 1
    EdgeShadowVSOutput Out = (EdgeShadowVSOutput)0;
    float4x4 WorldViewProjMatrix = EnvMapFaceWVPMatrices[face];
#endif

	//================================================================================
	//MikuMikuMoving独自のスキニング関数(MMM_SkinnedPosition)。座標を取得する。
	//================================================================================
	float4 position = MMM_SkinnedPosition(IN.Pos, IN.BlendWeight, IN.BlendIndices, IN.SdefC, IN.SdefR0, IN.SdefR1);

#if 1
    Out.pos = CalcEnvMapFacePosition(mul(position, WorldViewProjMatrix), face);
    Out.eye = CameraPosition - mul(position, WorldMatrix).xyz;
    return Out;
#else
    // カメラ視点のワールドビュー射影変換
    return mul( position, WorldViewProjMatrix );
#endif
}

//==============================================
// ピクセルシェーダ
//==============================================
#if 1
float4 Shadow_PS(EdgeShadowVSOutput IN, uniform int face) : COLOR
#else
float4 Shadow_PS() : COLOR
#endif
{
#if 1
    ClipEnvMapFace(IN.eye, face);
#endif

    return GroundShadowColor;
}

//==============================================
// 地面影描画テクニック
//==============================================
#if 1

POSTIBL_SHADOW_TEC_DEF

#else
technique ShadowTec < string MMDPass = "shadow"; > {
    pass DrawShadow {
        VertexShader = compile vs_2_0 Shadow_VS();
        PixelShader  = compile ps_2_0 Shadow_PS();
    }
}
#endif

///////////////////////////////////////////////////////////////////////////////////////////////
