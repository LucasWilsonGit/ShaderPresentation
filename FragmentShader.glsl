vec2 fragCoord = gl_FragCoord;

uniform vec2 iResolution;
uniform sampler2D iChannel0;
uniform lowp float iTime;

float LineDist(vec2 p, vec2 a, vec2 b) {
	vec2 ab = (b-a);
    vec2 ap = (p-a);
    float t = clamp(dot(ab,ap)/dot(ab,ab),0.,1.); //a=HcosTheta
    return length(ap-t*ab);
}

float r21(vec2 p) {
	return fract(sin(dot(p.xy ,vec2(12.9898,78.233))) * 4558.5453);
}

vec2 r22(vec2 p) {
    float f = r21(p);
    return vec2( f, floor(f)+fract(fract(f)*100.) );
}

vec2 GetDotPos(vec2 GridID) { 
    vec2 Offs = r22(GridID);
    return vec2( sin(iTime*.5*Offs.x), cos(iTime*.5*Offs.y) ) * .45 + .5;
}

float Line(vec2 p, vec2 a, vec2 b) {
    float d = LineDist(p,a,b);
    float m = smoothstep(.02,0., d);
    float dist = 1. - clamp(length(b-a)*.9, 0., 1.);
    float f = 1.;
    if (dist < .1) { f = 5.; }
    return m * dist * f;
}

float Layer(vec2 uv) {
    vec2 GridID = floor(uv*5.);
    vec2 CellPos = fract(uv*5.);
    vec2 MyDotPos = GetDotPos(GridID);
    
    float m = 0.;
    
    m += Line(CellPos, GetDotPos(GridID-vec2(1,0))-vec2(1,0), GetDotPos(GridID-vec2(0,1))-vec2(0,1));
    m += Line(CellPos, GetDotPos(GridID-vec2(1,0))-vec2(1,0), GetDotPos(GridID+vec2(0,1))+vec2(0,1));
    m += Line(CellPos, GetDotPos(GridID+vec2(1,0))+vec2(1,0), GetDotPos(GridID-vec2(0,1))-vec2(0,1));
    m += Line(CellPos, GetDotPos(GridID+vec2(1,0))+vec2(1,0), GetDotPos(GridID+vec2(0,1))+vec2(0,1));
    
    for (int x=-1;x<=1;x++) {
        for (int y=-1;y<=1;y++) {
            vec2 OtherGridID = GridID + vec2(x,y);
            m += Line(CellPos, MyDotPos, GetDotPos(OtherGridID) + vec2(x,y));
            //Draw line to other dots within local cell
            m += .2*smoothstep(.1+(sin(iTime*(r21(OtherGridID)+.5)*10.)+1.)*.1, 0., .05+length(CellPos-(GetDotPos(OtherGridID)+vec2(x,y))));
			//Draw overspill of dot glow from other cells (avoid artifacts)
        }
    }
    
    
    //Corner cutting cases on linesegment rendering
    
    return m;
}

#define TextLength 13.
//16 char row length in iChannel1 texture, so we will 
float[] Text = float[] (179.,184.,177.,162.,177.,179.,164.,181.,162.,190.,177.,189.,181.);

float TextMask(vec2 p) {
    return textureGrad(iChannel1, p, dFdx(p/16.), dFdy(p/16.)).r;
}

vec2 CharScreenPos(float charId) {
    float col = floor(charId/16.);
    float row = fract(charId/16.)*16.;
    return vec2(row/16.-.01/16.,col/16.);
}

vec2 CharRectPos(float charId, vec2 p) {
    vec2 Relative = CharScreenPos(charId) + vec2(-0.001,0.) + p/16.;
    return Relative;
}

float GetPixelTextMask(vec2 uv) {
    float m;
    
    highp float textRectWidth = 1.7;
    highp float textRectHeight = .333;

    float limX = (1.-textRectWidth)*.5;
    float limY = (1.-textRectHeight)*.5;
    
    vec2 StartPos = vec2(limX,limY);
    
     if (uv.x > limX && 1.-uv.x > limX && uv.y > limY && 1.-uv.y > limY) {
        
        vec2 RectPos = (uv-StartPos)/vec2(textRectWidth,textRectHeight);
    	float CharIndex = floor(RectPos.x*TextLength);
    	float GridX = fract(RectPos.x*(TextLength));
        vec2 CharPos = vec2(GridX,RectPos.y);
        
        
        
        //col = vec3(CharIndex/TextLength);
        m += TextMask(CharRectPos(Text[int(CharIndex)], CharPos*.7+.15));
        //m += RectPos.x;
    }
    
    return m;
}

#define StringLength 13
int[StringLength] Characters = int[StringLength] (16,23,12,16,16,16,16,16,16,16,16,16,16);

float GetSoundPeak(float Freq) { //range 0,1 freq range of song multiplied
    
    return (texelFetch(iChannel0, ivec2(iChannelResolution[0].x*Freq,0),0).x);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec3 fxcol =  0.5 + 0.5*cos(iTime*.1+vec3(0,2,4));
    vec3 col = vec3(0.);
    // Normalized pixel coordinates from center
    vec2 uv = fragCoord.xy/iResolution.xy-.5;
    uv.x*=iResolution.x/iResolution.y;
    
    float m = .025;
    float t = iTime*.05;
    
    float s = sin(t);
    float c = cos(t);
    mat2 rot = mat2(c,-s,s,c);
        
    for (float j=.01;j<=5.;j+=.25) {
        t+=j;
        float z = fract(t);
        float scale = mix(4., 0., z);
    	m += Layer(uv*rot*scale+j*20.) * smoothstep(0., 1.,fract(t));
    }
    
    col = fxcol * m * GetPixelTextMask(uv+.5) + fxcol * m * GetSoundPeak(.2);
    
    col += fxcol * m * (GetPixelTextMask(uv+.5)) * 5.;
    //col -= k;
    // Output to screen
    fragColor = vec4(col,1.0);
}
