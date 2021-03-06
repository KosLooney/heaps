package h3d.impl;
import kha.graphics4.StencilValue;
import h3d.impl.Driver;
import h3d.mat.Pass;
import h3d.mat.Stencil;

import kha.graphics4.ConstantLocation;
import kha.Framebuffer;
import kha.Image;
import kha.SystemImpl;
import kha.graphics4.BlendingFactor;
import kha.graphics4.BlendingOperation;
import kha.graphics4.CompareMode;
import kha.graphics4.ConstantLocation;
import kha.graphics4.CullMode;
import kha.graphics4.DepthStencilFormat;
import kha.graphics4.FragmentShader;
import kha.graphics4.IndexBuffer;
import kha.graphics4.PipelineState;
import kha.graphics4.StencilAction;
import kha.graphics4.TextureUnit;
import kha.graphics4.Usage;
import kha.graphics4.VertexData;
import kha.graphics4.VertexShader;
import kha.graphics4.VertexStructure;

class VertexWrapper {
	public var count:Int;
	public var stride:Int;
	public var data:haxe.ds.Vector<kha.FastFloat>;
	public var usage:Usage;
	public var vertexBuffers:Array<kha.graphics4.VertexBuffer>;
	public var mappedVertexBuffers:Map<Int, Int>;

	public function new(count:Int, stride:Int, usage:Usage) {
		this.count = count;
		this.stride = stride;
		data = new haxe.ds.Vector<kha.FastFloat>(count * stride);
		this.usage = usage;
		vertexBuffers = [];
		mappedVertexBuffers = new Map<Int, Int>();
	}
}

private class ShaderParameters {
	public var globals:ConstantLocation;
	public var params:ConstantLocation;
	public var textures:Array<TextureUnit> = [];
	public var cubeTextures:Array<TextureUnit> = [];

	public function new(pipeline:PipelineState, data:hxsl.RuntimeShader.RuntimeShaderData, prefix:String) {

		if(data.globalsSize > 0)
			globals = pipeline.getConstantLocation(prefix + "Globals");
		if(data.paramsSize > 0)
			params = pipeline.getConstantLocation(prefix + "Params");

		textures = [for( i in 0...data.texturesCount ) pipeline.getTextureUnit(prefix + "Textures[" + i + "]")];
		//cubeTextures = [for( i in 0...data.texturesCubeCount ) pipeline.getTextureUnit(prefix + "TexturesCube[" + i + "]")];
	}
}

private class Pipeline {
	public var pipeline:PipelineState;
	public var vertexParameters:ShaderParameters;
	public var fragmentParameters:ShaderParameters;	

	public function new(program:Program, material:Material) {
		pipeline = new PipelineState();		

		pipeline.vertexShader = program.vertexShader;
		pipeline.fragmentShader = program.fragmentShader;
		pipeline.inputLayout = program.structures;

		pipeline.cullMode = material.cullMode;
		pipeline.depthWrite = material.depthWrite;
		pipeline.depthMode = material.depthMode;
		pipeline.stencilMode = material.stencilMode;
		pipeline.stencilBothPass = material.stencilBothPass;
		pipeline.stencilDepthFail = material.stencilDepthFail;
		pipeline.stencilFail = material.stencilFail;
		pipeline.stencilReferenceValue = material.stencilReferenceValue;
		pipeline.stencilReadMask = material.stencilReadMask;
		pipeline.stencilWriteMask = material.stencilWriteMask;
		pipeline.blendSource = material.blendSource;
		pipeline.blendDestination = material.blendDestination;
		pipeline.blendOperation = material.blendOperation;
		pipeline.alphaBlendSource = material.alphaBlendSource;
		pipeline.alphaBlendDestination = material.alphaBlendDestination;
		pipeline.alphaBlendOperation = material.alphaBlendOperation;
		pipeline.colorWriteMaskRed = material.colorWriteMaskRed;
		pipeline.colorWriteMaskGreen = material.colorWriteMaskGreen;
		pipeline.colorWriteMaskBlue = material.colorWriteMaskBlue;
		pipeline.colorWriteMaskAlpha = material.colorWriteMaskAlpha;

		pipeline.compile();

		vertexParameters = new ShaderParameters(pipeline, program.vertexShaderData, "vertex");		
		fragmentParameters = new ShaderParameters(pipeline, program.fragmentShaderData, "fragment");
	}
}

private typedef ShaderCompiler = hxsl.GlslOut;

private class CompiledAttribute {
	public var index : Int;
	public var type : Int;
	public var size : Int;
	public var offset : Int;
	public var divisor : Int;
	public var name : String;
	public function new() {
	}
}

private class Program {
	public var id:Int;
	public var vertexShader:VertexShader;
	public var fragmentShader:FragmentShader;
	public var structures:Array<VertexStructure>;
	public var vertexShaderData:hxsl.RuntimeShader.RuntimeShaderData;
	public var fragmentShaderData:hxsl.RuntimeShader.RuntimeShaderData;
	public var inputs : InputNames;
	public var attribs : Array<CompiledAttribute>;	

	public function new(shader:hxsl.RuntimeShader, glES, shaderVersion) {
		this.id = shader.id;
		attribs = [];

		var glout = new ShaderCompiler();
		glout.glES = glES;
		glout.version = shaderVersion;

		vertexShader = VertexShader.fromSource(glout.run(shader.vertex.data));
		fragmentShader = FragmentShader.fromSource(glout.run(shader.fragment.data));

		//trace("Vertex shader:\n" + glout.run(shader.vertex.data));
		//trace("Fragment shader:\n" + glout.run(shader.fragment.data));
		
		var inputVars = [];
		for( v in shader.vertex.data.vars ){
			switch( v.kind ) {
			case Input:
				inputVars.push(v.name);	
			default:
			}     
		}		
		inputs = InputNames.get(inputVars);

		var structure = new VertexStructure();
		//var stride = 0;
		for( v in shader.vertex.data.vars )
			switch( v.kind ) {
			case Input:

				var t = GL.FLOAT;
				var size = switch( v.type ) {
				case TVec(n, _): n;
				case TBytes(n): t = GL.BYTE; n;
				case TFloat: 1;
				default: throw "assert " + v.type;
				}

				var data: VertexData;
				switch( v.type ) {
				case TVec(n, _):
					data = switch ( n ) {
						case 2: data = VertexData.Float2;
						case 3: data = VertexData.Float3;
						case 4: data = VertexData.Float4;
						default: throw "assert " + v.type;
					}
				case TBytes(n): throw "assert " + v.type;
				case TFloat: data = VertexData.Float1;
				default: throw "assert " + v.type;
				}

			//	var index = SystemImpl.gl.getAttribLocation(p.p, glout.varNames.exists(v.id) ? glout.varNames.get(v.id) : v.name);
			//	if( index < 0 ) {
			//		trace(glout.varNames.get(v.id) + "-----" + v.name);
			//		stride += size;
			//		continue;
			//	}

				var a = new CompiledAttribute();
					a.type = t;
					a.size = size;
					//a.index = index;
					//a.offset = p.stride;
					a.divisor = 0;
					a.name = v.name;
					if( v.qualifiers != null ) {
						for( q in v.qualifiers )
							switch( q ) {
							case PerInstance(n): a.divisor = n;
							default:
							}
					}
					attribs.push(a);
					
				structure.add(v.name, data);
			default:
			}  
			
		//trace(structure);
		this.structures = [structure];
		
		vertexShaderData = shader.vertex;
		fragmentShaderData = shader.fragment;
	}
}

private class Material {
	public function new(id:Int, name:String) {
		this.id = id;
		this.name = name;
		inputLayout = null;
		vertexShader = null;
		fragmentShader = null;

		cullMode = CullMode.None;

		depthWrite = false;
		depthMode = CompareMode.Always;

		stencilMode = CompareMode.Always;
		stencilBothPass = StencilAction.Keep;
		stencilDepthFail = StencilAction.Keep;
		stencilFail = StencilAction.Keep;
		stencilReferenceValue = kha.graphics4.StencilValue.Static(0);
		stencilReadMask = 0xff;
		stencilWriteMask = 0xff;

		blendSource = BlendingFactor.BlendOne;
		blendDestination = BlendingFactor.BlendZero;
		blendOperation = BlendingOperation.Add;
		alphaBlendSource = BlendingFactor.BlendOne;
		alphaBlendDestination = BlendingFactor.BlendZero;
		alphaBlendOperation = BlendingOperation.Add;
		
		colorWriteMaskRed = true;
		colorWriteMaskGreen = true;
		colorWriteMaskBlue = true;
		colorWriteMaskAlpha = true;
	}

	public var id:Int;
	public var name:String;

	public var inputLayout:Array<VertexStructure>;
	public var vertexShader:VertexShader;
	public var fragmentShader:FragmentShader;

	public var cullMode:CullMode;

	public var depthWrite:Bool;
	public var depthMode:CompareMode;

	public var stencilMode:CompareMode;
	public var stencilBothPass:StencilAction;
	public var stencilDepthFail:StencilAction;
	public var stencilFail:StencilAction;
	public var stencilReferenceValue:StencilValue;
	public var stencilReadMask:Int;
	public var stencilWriteMask:Int;

	public var blendSource:BlendingFactor;
	public var blendDestination:BlendingFactor;
	public var blendOperation:BlendingOperation;
	public var alphaBlendSource:BlendingFactor;
	public var alphaBlendDestination:BlendingFactor;
	public var alphaBlendOperation:BlendingOperation;
	
	public var colorWriteMaskRed:Bool;
	public var colorWriteMaskGreen:Bool;
	public var colorWriteMaskBlue:Bool;
	public var colorWriteMaskAlpha:Bool;
}

private typedef GL = js.html.webgl.GL;

class KhaDriver extends h3d.impl.Driver {

	var mrtExt : { function drawBuffersWEBGL( colors : Array<Int> ) : Void; };

	public static var framebuffer: kha.Framebuffer;
	public static var g: kha.graphics4.Graphics;
	var programs = new Map<Int, Program>();
			
	var maxCompressedTexturesSupport = 0;

	var bufferHeight : Int;
	var bufferWidth : Int;	

	var curProgram: Program = null;
	var curBuffer : h3d.Buffer;
	var debug : Bool;
	var drawMode : Int;

	var glES : Null<Float>;

	var shaderVersion : Null<Int>;

	
	var pipelines = new Map<String, Pipeline>();
	var curPipeline: Pipeline;
	var lastVertexGlobals:h3d.shader.Buffers.ShaderBufferData;
	var lastVertexParams:h3d.shader.Buffers.ShaderBufferData;
	var lastVertexTextures:haxe.ds.Vector<h3d.mat.Texture>;
	var lastVertexBuffers:haxe.ds.Vector<Buffer>;

	var lastFragmentGlobals:h3d.shader.Buffers.ShaderBufferData;
	var lastFragmentParams:h3d.shader.Buffers.ShaderBufferData;
	var lastFragmentTextures:haxe.ds.Vector<h3d.mat.Texture>;
	var lastFragmentBuffers:haxe.ds.Vector<Buffer>;


	public static var outOfMemoryCheck = #if js false #else true #end;

	public function new(antiAlias: Int) {
		var v : String = SystemImpl.gl.getParameter(GL.VERSION);
		var reg = ~/ES ([0-9]+\.[0-9]+)/;
		if( reg.match(v) )
			glES = Std.parseFloat(reg.matched(1));

		var reg = ~/[0-9]+\.[0-9]+/;
		var v : String = SystemImpl.gl.getParameter(GL.SHADING_LANGUAGE_VERSION);
		if( reg.match(v) ) {
			#if js
			glES = Std.parseFloat(reg.matched(0));
			#end
			shaderVersion = Math.round( Std.parseFloat(reg.matched(0)) * 100 );
		}
		drawMode = GL.TRIANGLES;
	}

	override function hasFeature( f : Feature ) : Bool {
		#if js
		return features.get(f);
		#else
		return true;
		#end
	}

	#if js
	var features : Map<Feature,Bool> = new Map();
	function makeFeatures() {
		for( f in Type.allEnums(Feature) )
			features.set(f,checkFeature(f));
		if( SystemImpl.gl.getExtension("WEBGL_compressed_texture_s3tc") != null )
			maxCompressedTexturesSupport = 3;
	}
	function checkFeature( f : Feature ) {
		return switch( f ) {

		case HardwareAccelerated, AllocDepthBuffer, BottomLeftCoords, Wireframe:
			true;

		case StandardDerivatives, MultipleRenderTargets, SRGBTextures if( glES >= 3 ):
			true;

		case ShaderModel3 if( glES >= 3 ):
			true;

		case FloatTextures if( glES >= 3 ):
			SystemImpl.gl.getExtension('EXT_color_buffer_float') != null && SystemImpl.gl.getExtension("OES_texture_float_linear") != null; // allow render to 16f/32f textures (not standard in webgl 2)

		case StandardDerivatives:
			SystemImpl.gl.getExtension('OES_standard_derivatives') != null;

		case FloatTextures:
			SystemImpl.gl.getExtension('OES_texture_float') != null && SystemImpl.gl.getExtension('OES_texture_float_linear') != null &&
			SystemImpl.gl.getExtension('OES_texture_half_float') != null && SystemImpl.gl.getExtension('OES_texture_half_float_linear') != null;

		case SRGBTextures:
			SystemImpl.gl.getExtension('EXT_sRGB') != null;

		case MultipleRenderTargets:
			mrtExt != null || (mrtExt = SystemImpl.gl.getExtension('WEBGL_draw_buffers')) != null;

		case InstancedRendering:
			return (glES >= 3) ? true : SystemImpl.gl.getExtension("ANGLE_instanced_arrays") != null;

		default:
			false;
		}
	}

	#end

	override public function setRenderFlag( r : RenderFlag, value : Int ) {
	}

	override public function isSupportedFormat( fmt : h3d.mat.Data.TextureFormat ) {
		return false;
	}

	override public function isDisposed() {
		return SystemImpl.gl.isContextLost();
	}

	override function logImpl( str : String ) {
		#if js
		untyped console.log(str);
		#else
		Sys.println(str);
		#end
	}
	
	override public function begin( frame : Int ) {
		curPipeline = null;
		curProgram = null;
		curBuffer = null;

		g.begin();
	}

	override public function generateMipMaps( texture : h3d.mat.Texture ) {
		throw "Mipmaps auto generation is not supported on this platform";
	}

	override public function getNativeShaderCode( shader : hxsl.RuntimeShader ) : String {
		return "// vertex:\n" + ShaderCompiler.compile(shader.vertex.data) + "// fragment:\n" + ShaderCompiler.compile(shader.fragment.data);
	}

	override public function clear( ?color : h3d.Vector, ?depth : Float, ?stencil : Int ) {
		g.clear(color != null ? kha.Color.fromFloats(color.r, color.g, color.b, color.a) : null, depth, stencil);
	}

	override public function captureRenderBuffer( pixels : hxd.Pixels ) {
		throw "captureRenderBuffer";
	}

	override public function capturePixels( tex : h3d.mat.Texture, layer : Int, mipLevel : Int, ?region : h2d.col.IBounds ) : hxd.Pixels {
		throw "Can't capture pixels on this platform";
		return null;
	}

	override public function getDriverName( details : Bool ) {
		var render = SystemImpl.gl.getParameter(GL.RENDERER);
		if( details )
			render += " GLv" + SystemImpl.gl.getParameter(GL.VERSION);
		else
			render = render.split("/").shift(); // GeForce reports "/PCIe/SSE2" extension
		#if js
		render = render.split("WebGL ").join("");
		#end
		return "OpenGL "+render;
	}

	override public function init( onCreate : Bool -> Void, forceSoftware = false ) {
		onCreate(false);
	}

	override public function resize( width : Int, height : Int ) {
		bufferWidth = width;
		bufferHeight = height;

		@:privateAccess if( defaultDepth != null ) {
			disposeDepthBuffer(defaultDepth);
			defaultDepth.width = this.bufferWidth;
			defaultDepth.height = this.bufferHeight;
			defaultDepth.b = allocDepthBuffer(defaultDepth);
		}
	}

	override public function selectShader( shader : hxsl.RuntimeShader ) {
		var program = programs.get(shader.id);
		if( program == null ) {
			program = new Program(shader, glES, shaderVersion);
			programs.set(shader.id, program);
		}
		if( curProgram == program ) return false;

		curProgram = program;
		curBuffer = null;
		return true;
	}

	var materials = new Map<Int, Material>();
	var curMaterial: Material;

	override public function selectMaterial( pass : h3d.mat.Pass ) {
	
		if(pass.name != ""){
			if (materials.exists(@:privateAccess pass.uuid)) {
				curMaterial = materials.get(@:privateAccess pass.uuid);
				return;
			}
		}		
		
		var material = new Material(@:privateAccess pass.uuid, pass.name);
		var bits = @:privateAccess pass.bits;
		if( bits & Pass.culling_mask != 0 ) {
			var cull = Pass.getCulling(bits);
			if( cull == 0 )
				material.cullMode = kha.graphics4.CullMode.None;
			else {
				material.cullMode = CULLFACES[cull];
			}
		}
		if( bits & (Pass.blendSrc_mask | Pass.blendDst_mask | Pass.blendAlphaSrc_mask | Pass.blendAlphaDst_mask) != 0 ) {

			var csrc = Pass.getBlendSrc(bits);
			var cdst = Pass.getBlendDst(bits);
			var asrc = Pass.getBlendAlphaSrc(bits);
			var adst = Pass.getBlendAlphaDst(bits);
			material.blendSource = BLEND[csrc];
			material.alphaBlendSource = BLEND[asrc];
			material.blendDestination = BLEND[cdst];
			material.alphaBlendDestination = BLEND[adst];
		}
		if( bits & (Pass.blendOp_mask | Pass.blendAlphaOp_mask) != 0 ) {
			var cop = Pass.getBlendOp(bits);
			var aop = Pass.getBlendAlphaOp(bits);
			material.blendOperation = OP[cop];
			material.alphaBlendOperation = OP[aop];
		}
		if( bits & Pass.depthWrite_mask != 0 )
			material.depthWrite = true;
		if( bits & Pass.depthTest_mask != 0 ) {
			var cmp = Pass.getDepthTest(bits);
			material.depthMode = COMPARE[cmp];
		}
		
		/*
		if( bits & Pass.colorMask_mask != 0 ) {
			var m = Pass.getColorMask(bits);
			material.colorWriteMaskRed   = m & 1 != 0;
			material.colorWriteMaskGreen = m & 2 != 0;
			material.colorWriteMaskBlue  = m & 4 != 0;
			material.colorWriteMaskAlpha = m & 8 != 0;
		}
		*/

		// TODO: two-sided stencil
		var s = pass.stencil;
		
		if( s != null ) {
			/*
			var opBits = @:privateAccess s.opBits;
			var frBits = @:privateAccess s.frontRefBits;
			var brBits = @:privateAccess s.backRefBits;

			if( opBits & (Stencil.frontSTfail_mask | Stencil.frontDPfail_mask | Stencil.frontDPpass_mask) != 0 ) {
				material.stencilFail = STENCIL_OP[Stencil.getFrontSTfail(opBits)];
				material.stencilDepthFail = STENCIL_OP[Stencil.getFrontDPfail(opBits)];
				material.stencilBothPass = STENCIL_OP[Stencil.getFrontDPpass(opBits)];
			}

			if( opBits & (Stencil.backSTfail_mask | Stencil.backDPfail_mask | Stencil.backDPpass_mask) != 0 ) {
				material.stencilFail = STENCIL_OP[Stencil.getBackSTfail(opBits)];
				material.stencilDepthFail = STENCIL_OP[Stencil.getBackDPfail(opBits)];
				material.stencilBothPass = STENCIL_OP[Stencil.getBackDPpass(opBits)];
			}

			if( (opBits & Stencil.frontTest_mask) | (frBits & (Stencil.frontRef_mask | Stencil.frontReadMask_mask)) != 0 ) {
				material.stencilMode = COMPARE[Stencil.getFrontTest(opBits)];
				material.stencilReferenceValue = Stencil.getFrontRef(frBits);
				material.stencilReadMask = Stencil.getFrontReadMask(frBits);
			}

			if( (opBits & Stencil.backTest_mask) | (brBits & (Stencil.backRef_mask | Stencil.backReadMask_mask)) != 0 ) {
				material.stencilMode = COMPARE[Stencil.getBackTest(opBits)];
				material.stencilReferenceValue = Stencil.getBackRef(brBits);
				material.stencilReadMask = Stencil.getBackReadMask(brBits);
			}

			if( frBits & Stencil.frontWriteMask_mask != 0 )
				material.stencilWriteMask = Stencil.getFrontWriteMask(frBits);

			if( brBits & Stencil.backWriteMask_mask != 0 )
				material.stencilWriteMask = Stencil.getBackWriteMask(brBits);

			*/
		}		

		if(pass.name != ""){
			materials.set(material.id, material);
		}
		curMaterial = material;
	}

	override public function uploadShaderBuffers( buffers : h3d.shader.Buffers, which : h3d.shader.Buffers.BufferKind ) {
		switch( which ) {
			case Globals:
				lastVertexGlobals = buffers.vertex.globals;
				lastFragmentGlobals = buffers.fragment.globals;
			case Params:
				lastVertexParams = buffers.vertex.params;
				lastFragmentParams = buffers.fragment.params;
			case Buffers:
				lastVertexBuffers = buffers.vertex.buffers;
				lastFragmentBuffers = buffers.fragment.buffers;				
			case Textures:
				lastVertexTextures = buffers.vertex.tex;
				lastFragmentTextures = buffers.fragment.tex;
			}
	}	

	override public function getShaderInputNames() : InputNames {
		return curProgram.inputs;
	}

	override public function selectBuffer( v :Buffer ) {

		if( v == curBuffer ){
			var wrapper = @:privateAccess v.buffer.vbuf;
			g.setVertexBuffers(wrapper.vertexBuffers);
			return;
		}			

		if( curBuffer != null && v.buffer == curBuffer.buffer && v.buffer.flags.has(RawFormat) == curBuffer.flags.has(RawFormat) ) {
			curBuffer = v;
			return;
		}

		if( curProgram == null )
			throw "No shader selected";

		curBuffer = v;

		var wrapper = @:privateAccess v.buffer.vbuf;		
		if( wrapper.vertexBuffers.length == 0) {
			var vertexBuffer = new kha.graphics4.VertexBuffer(wrapper.count, curProgram.structures[0], wrapper.usage, false);
			var vertices = vertexBuffer.lock();
			for( i in 0...wrapper.data.length ) {
				vertices.set(i, wrapper.data[i]);
			}
			vertexBuffer.unlock();
			wrapper.vertexBuffers.push(vertexBuffer);
		}		
		g.setVertexBuffers(wrapper.vertexBuffers);
	}

	override public function selectMultiBuffers( buffers : Buffer.BufferOffset ) {

		/*
		var curBufferId = buffers.buffer.id;
		while( buffers != null ) {			
			if(curBufferId != buffers.buffer.id){
				trace('Switch buffer');
			}			
			buffers = buffers.next;
		}
		*/
				
		var wrapper = @:privateAccess buffers.buffer.buffer.vbuf;
		if(!wrapper.mappedVertexBuffers.exists(curProgram.id)) {	
			wrapper.mappedVertexBuffers.set(curProgram.id, wrapper.vertexBuffers.length);
			var vertexBuffer = new kha.graphics4.VertexBuffer(wrapper.count, curProgram.structures[0], wrapper.usage, false);	
			var vertices = vertexBuffer.lock();
			for( i in 0...wrapper.data.length ) {
				vertices.set(i, wrapper.data[i]);
			}
			vertexBuffer.unlock();
			wrapper.vertexBuffers.push(vertexBuffer);
		}
		var vertexBuffer = wrapper.vertexBuffers[wrapper.vertexBuffers.length-1];
		g.setVertexBuffers([vertexBuffer]);
	}	

	function selectPipeline() {
		var key = curMaterial.id+"_"+curProgram.id;
		var pipeline = pipelines.get(key);
		if( pipeline == null ) {
			
			pipeline = new Pipeline(curProgram, curMaterial);
			pipelines.set(key, pipeline);

			
		}
		if( pipeline != curPipeline ) {
			g.setPipeline(pipeline.pipeline);
			curPipeline = pipeline;
		}
	}

	override public function draw( ibuf : IndexBuffer, startIndex : Int, ntriangles : Int ) {
	
		/*
		if(ibuf.count() != (ntriangles*3)){

			// A 'trick' to create indices for a non-indexed vertex data
			var indices:Array<Int> = [];
			for (i in 0...Std.int(ntriangles*3)) {
				indices.push(i);
			}

			// Create index buffer
			var indexBuffer:kha.graphics4.IndexBuffer = new kha.graphics4.IndexBuffer(
				indices.length, // Number of indices for our cube
				Usage.StaticUsage // Index data will stay the same
			);
			
			// Copy indices to index buffer
			var iData = indexBuffer.lock();
			for (i in 0...iData.length) {
				iData[i] = indices[i];
			}
			indexBuffer.unlock();			
			//trace(indexBuffer.count() + "--- " + ntriangles*3);
			g.setIndexBuffer(indexBuffer);
		}
		else
		{
			*/
			g.setIndexBuffer(ibuf);
			/*
		}
		*/

		selectPipeline();		

		if ( lastVertexGlobals != null ) {
			if( curPipeline.vertexParameters.globals != null ) {
				g.setFloats(curPipeline.vertexParameters.globals, cast lastVertexGlobals);
			}
			lastVertexGlobals = null;
		}
		if ( lastFragmentGlobals != null ) {
			if( curPipeline.fragmentParameters.globals != null ) {
				g.setFloats(curPipeline.fragmentParameters.globals, cast lastFragmentGlobals);
			}
			lastFragmentGlobals = null;
		}
		if ( lastVertexParams != null ) {
			if( curPipeline.vertexParameters.params != null ) {
				g.setFloats(curPipeline.vertexParameters.params, cast lastVertexParams);
			}
			lastVertexParams = null;
		}
		if ( lastFragmentParams != null ) {
			if( curPipeline.fragmentParameters.params != null ) {
				g.setFloats(curPipeline.fragmentParameters.params, cast lastFragmentParams);
			}
			lastFragmentParams = null;
		}

		if ( lastVertexTextures != null ) {
			for( i in 0...curPipeline.vertexParameters.textures.length/*+ curPipeline.vertexParameters.cubeTextures.length*/ ) {
				var texture = lastVertexTextures[i];
				var isCube = i >= curPipeline.vertexParameters.textures.length;
				if( texture != null && !texture.isDisposed() ) {
					if( isCube ) {
						throw "CubeTexture";
					}
					else {
						g.setTexture(curPipeline.vertexParameters.textures[i], texture.t);
						var mip = Type.enumIndex(texture.mipMap);
						var filter = Type.enumIndex(texture.filter);
						var wrap = Type.enumIndex(texture.wrap);
						g.setTextureParameters(curPipeline.vertexParameters.textures[i], TWRAP[wrap], TWRAP[wrap], TFILTERS[filter], TFILTERS[filter], TMIPS[mip]);
					}					
				}
			}
			lastVertexTextures = null;
		}
		if ( lastFragmentTextures != null ) {			
			for( i in 0...curPipeline.fragmentParameters.textures.length/* + curPipeline.fragmentParameters.cubeTextures.length*/ ) {
				var texture = lastFragmentTextures[i];
				var isCube = i >= curPipeline.fragmentParameters.textures.length;
				if( texture != null && !texture.isDisposed() ) {
					if( isCube ) {
						throw "CubeTexture";
					}
					else {

						g.setTexture(curPipeline.fragmentParameters.textures[i], texture.t);
						var mip = Type.enumIndex(texture.mipMap);
						var filter = Type.enumIndex(texture.filter);
						var wrap = Type.enumIndex(texture.wrap);
						g.setTextureParameters(curPipeline.fragmentParameters.textures[i], TWRAP[wrap], TWRAP[wrap], TFILTERS[filter], TFILTERS[filter], TMIPS[mip]);
					}					
				}
			}
			lastFragmentTextures = null;
		}

		g.drawIndexedVertices(startIndex, Std.int(ntriangles * 3));	
	}

	override public function drawInstanced( ibuf : IndexBuffer, commands : h3d.impl.InstanceBuffer ) {
		throw "drawInstanced";
	}

	override public function setRenderZone( x : Int, y : Int, width : Int, height : Int ) {
		if( x == 0 && y == 0 && width < 0 && height < 0 )
			g.disableScissor()
		else
			g.scissor(x, y, width, height);
		
	}

	override public function setRenderTarget( tex : Null<h3d.mat.Texture>, layer = 0, mipLevel = 0 ) {
		if( tex == null ) {
			g.end();
			g = framebuffer.g4;
			g.begin();
		}
		else {
			g.end();
			g = tex.t.g4;
			g.begin();
		}
	}

	override public function setRenderTargets( textures : Array<h3d.mat.Texture> ) {
		throw "setRenderTargets";
	}

	override public function allocDepthBuffer( b : h3d.mat.DepthBuffer ) : DepthBuffer {
		if( b.format == null )
			@:privateAccess b.format = #if js (glES >= 3 ? Depth24Stencil8 : Depth16) #else Depth24Stencil8 #end;

		var khaImg = cast(kha.Image.createRenderTarget(b.width, b.height, null, DepthStencilFormat.Depth24Stencil8, 1, 0), kha.WebGLImage);
		return { r :cast khaImg #if multidriver, driver : this #end };
	}

	override public function disposeDepthBuffer( b : h3d.mat.DepthBuffer ) {
		@:privateAccess if( b.b != null && b.b.r != null ) {
			/*
			SystemImpl.gl.deleteRenderbuffer(b.b.r);
			*/
			//b.b.r.unload();
			b.b = null;
		}
	}

	static var firstgetDefaultDepthBuffer = true;

	var defaultDepth : h3d.mat.DepthBuffer;
	override public function getDefaultDepthBuffer() : h3d.mat.DepthBuffer {
		if( defaultDepth != null )
			return defaultDepth;
		defaultDepth = new h3d.mat.DepthBuffer(0, 0);
		@:privateAccess {
			defaultDepth.width = this.bufferWidth;
			defaultDepth.height = this.bufferHeight;
			defaultDepth.b = allocDepthBuffer(defaultDepth);
		}
		return defaultDepth;
	}

	inline function discardError() {
		if( outOfMemoryCheck ) SystemImpl.gl.getError(); // make sure to reset error flag
	}

	override public function present() {		
		throw "present";
	}

	override public function end() {
		#if !js
		g.end();
		#end
	}

	override public function setDebug( d : Bool ) {
		this.debug = d;
	}

	override public function allocTexture( t : h3d.mat.Texture ) : Texture {
		discardError();
		if( t.flags.has(Target) )
			return Image.createRenderTarget(t.width, t.height);
		else
			return Image.create(t.width, t.height);
	}

	override public function allocIndexes( count : Int, is32 : Bool ) : IndexBuffer {
		discardError();
		return new kha.graphics4.IndexBuffer(count, StaticUsage);
	}

	override public function allocVertexes( m : ManagedBuffer ) : VertexBuffer {
		discardError();
		return new VertexWrapper(m.size, m.stride, m.flags.has(Dynamic) ? Usage.DynamicUsage : Usage.StaticUsage);
	}

	override public function allocInstanceBuffer( b : h3d.impl.InstanceBuffer, bytes : haxe.io.Bytes ) {
		throw "allocInstanceBuffer";
	}

	override public function disposeTexture( t : h3d.mat.Texture ) {
		throw "disposeTexture";
	}

	override public function disposeIndexes( i : IndexBuffer ) {
		throw "disposeIndexes";
	}

	override public function disposeVertexes( v : VertexBuffer ) {
		throw "disposeVertexes";
	}

	override public function disposeInstanceBuffer( b : h3d.impl.InstanceBuffer ) {
		b.data = null;
		b.dispose();
	}

	override public function uploadIndexBuffer( i : IndexBuffer, startIndice : Int, indiceCount : Int, buf : hxd.IndexBuffer, bufPos : Int ) {
		var indices = i.lock(startIndice, indiceCount);
		for( i in 0...indiceCount ) {
			indices.set(i, buf[bufPos + i]);
		}
		i.unlock();
	}

	override public function uploadIndexBytes( i : IndexBuffer, startIndice : Int, indiceCount : Int, buf : haxe.io.Bytes , bufPos : Int ) {
		throw "uploadIndexBytes";
	}

	override function uploadVertexBuffer( v : VertexBuffer, startVertex : Int, vertexCount : Int, buf : hxd.FloatBuffer, bufPos : Int ) {
		for( i in 0...vertexCount * v.stride ) {
			v.data.set(i, buf[bufPos + i]);
		}		
	}

	override public function uploadVertexBytes( v : VertexBuffer, startVertex : Int, vertexCount : Int, buf : haxe.io.Bytes, bufPos : Int ) {
		trace(v);
		throw "uploadVertexBytes";
	}

	override public function uploadTextureBitmap( t : h3d.mat.Texture, bmp : hxd.BitmapData, mipLevel : Int, side : Int ) {
		var pixels = bmp.getPixels();
		uploadTexturePixels(t, pixels, mipLevel, side);
		pixels.dispose();
	}

	override public function uploadTexturePixels( t : h3d.mat.Texture, pixels : hxd.Pixels, mipLevel : Int, side : Int ) {

		//pixels.convert(t.format);
		//pixels.setFlip(false);

		var data = t.t.lock(mipLevel);	
		
		for( i in 0...pixels.bytes.length ) {			
			data.set(i, pixels.bytes.get(i));
		}

		t.t.unlock();		
	}

	override public function readVertexBytes( v : VertexBuffer, startVertex : Int, vertexCount : Int, buf : haxe.io.Bytes, bufPos : Int ) {
		throw "Driver does not allow to read vertex bytes";
	}

	override public function readIndexBytes( v : IndexBuffer, startVertex : Int, vertexCount : Int, buf : haxe.io.Bytes, bufPos : Int ) {
		throw "Driver does not allow to read index bytes";
	}

	/**
		Returns true if we could copy the texture, false otherwise (not supported by driver or mismatch in size/format)
	**/
	override public function copyTexture( from : h3d.mat.Texture, to : h3d.mat.Texture ) {
		throw "copyTexture";
		return false;
	}

	// --- QUERY API

	override public function allocQuery( queryKind : QueryKind ) : Query {
		return null;
	}

	override public function deleteQuery( q : Query ) {
	}

	override public function beginQuery( q : Query ) {
	}

	override public function endQuery( q : Query ) {
	}

	override public function queryResultAvailable( q : Query ) {
		return true;
	}

	override public function queryResult( q : Query ) {
		return 0.;
	}

	static var CULLFACES = [
		kha.graphics4.CullMode.None,
		kha.graphics4.CullMode.CounterClockwise,
		kha.graphics4.CullMode.Clockwise,
		kha.graphics4.CullMode.None,
	];

	static var BLEND = [
		kha.graphics4.BlendingFactor.BlendOne,
		kha.graphics4.BlendingFactor.BlendZero,
		kha.graphics4.BlendingFactor.SourceAlpha,
		kha.graphics4.BlendingFactor.SourceColor,
		kha.graphics4.BlendingFactor.DestinationAlpha,
		kha.graphics4.BlendingFactor.DestinationColor,
		kha.graphics4.BlendingFactor.InverseSourceAlpha,
		kha.graphics4.BlendingFactor.InverseSourceColor,
		kha.graphics4.BlendingFactor.InverseDestinationAlpha,
		kha.graphics4.BlendingFactor.InverseDestinationColor,
		kha.graphics4.BlendingFactor.Undefined, // CONSTANT_COLOR
		kha.graphics4.BlendingFactor.Undefined, // CONSTANT_ALPHA
		kha.graphics4.BlendingFactor.Undefined, // ONE_MINUS_CONSTANT_COLOR
		kha.graphics4.BlendingFactor.Undefined, // ONE_MINUS_CONSTANT_ALPHA
		kha.graphics4.BlendingFactor.Undefined, // SRC_ALPHA_SATURATE
	];

	static var OP = [
		kha.graphics4.BlendingOperation.Add,
		kha.graphics4.BlendingOperation.Subtract,
		kha.graphics4.BlendingOperation.ReverseSubtract,
	];

	static var COMPARE = [
		kha.graphics4.CompareMode.Always,
		kha.graphics4.CompareMode.Never,
		kha.graphics4.CompareMode.Equal,
		kha.graphics4.CompareMode.NotEqual,
		kha.graphics4.CompareMode.Greater,
		kha.graphics4.CompareMode.GreaterEqual,
		kha.graphics4.CompareMode.Less,
		kha.graphics4.CompareMode.LessEqual,
	];

	static var STENCIL_OP = [
		kha.graphics4.StencilAction.Keep,
		kha.graphics4.StencilAction.Zero,
		kha.graphics4.StencilAction.Replace,
		kha.graphics4.StencilAction.Increment,
		kha.graphics4.StencilAction.IncrementWrap,
		kha.graphics4.StencilAction.Decrement,
		kha.graphics4.StencilAction.DecrementWrap,
		kha.graphics4.StencilAction.Invert,
	];

	static var TFILTERS = [
		kha.graphics4.TextureFilter.PointFilter,
		kha.graphics4.TextureFilter.LinearFilter,
		kha.graphics4.TextureFilter.AnisotropicFilter
	];

	static var TMIPS = [
		kha.graphics4.MipMapFilter.NoMipFilter,
		kha.graphics4.MipMapFilter.PointMipFilter,
		kha.graphics4.MipMapFilter.LinearMipFilter,
	];

	static var TWRAP = [
		kha.graphics4.TextureAddressing.Clamp,
		kha.graphics4.TextureAddressing.Repeat,
	];
}