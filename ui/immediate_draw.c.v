// vfmt off
// Draw adapters keep custom primitives in the active gg command stream on
// both older sokol-gl builds and newer builds with a per-context renderer.
@[has_globals]
module ui2

$if (android || linux || freebsd || openbsd || netbsd || dragonfly || solaris || ((macos || windows) && ui2_custom_rendering ?)) && !ui2_headless ? {
	import gg
	import sokol.gfx
	import sokol.sgl

	__global im_draw_ready = false
	__global im_alpha_pipe = sgl.Pipeline{}

	// im_draw_setup prepares sokol-gl for the immediate backend. gg's pure-V
	// renderer no longer sets sgl up, so ui2 must do it explicitly. Called once
	// from on_init, after Sokol's setup and before the first frame, so every
	// toolchain runs it exactly once.
	fn im_draw_setup() {
		if im_draw_ready {
			return
		}
		sgl.setup(&sgl.Desc{})
		im_draw_ready = true
	}

	// im_alpha_pipeline is the alpha-blend pipeline the immediate draws load:
	// source alpha over one-minus-source-alpha, the blend gg installed for
	// these draws before its pure-V renderer moved the pipeline type.
	fn im_alpha_pipeline() sgl.Pipeline {
		if im_alpha_pipe.id != 0 {
			return im_alpha_pipe
		}
		mut desc := gfx.PipelineDesc{}
		unsafe { vmemset(&desc, 0, int(sizeof(desc))) }
		desc.label = c'ui2-alpha-pipeline'
		desc.colors[0] = gfx.ColorTargetState{
			blend: gfx.BlendState{
				enabled:        true
				src_factor_rgb: .src_alpha
				dst_factor_rgb: .one_minus_src_alpha
			}
		}
		im_alpha_pipe = sgl.make_pipeline(&desc)
		return im_alpha_pipe
	}

	// New gg batches through ctx.r; old gg batches through sokol-gl. Always
	// submit into the same renderer that ctx.begin/end prepare and flush.
	fn im_load_alpha(ctx &gg.Context) {
		$for field in gg.Context.fields {
			$if field.name == 'r' {
				ctx.r.load_pipeline(ctx.pipeline.alpha)
				return
			}
		}
		sgl.load_pipeline(im_alpha_pipeline())
	}

	@[inline]
	fn im_enable_texture(ctx &gg.Context) {
		$for field in gg.Context.fields {
			$if field.name == 'r' {
				ctx.r.enable_texture()
				return
			}
		}
		sgl.enable_texture()
	}

	@[inline]
	fn im_disable_texture(ctx &gg.Context) {
		$for field in gg.Context.fields {
			$if field.name == 'r' {
				ctx.r.disable_texture()
				return
			}
		}
		sgl.disable_texture()
	}

	@[inline]
	fn im_texture(ctx &gg.Context, img gfx.Image, sampler gfx.Sampler) {
		$for field in gg.Context.fields {
			$if field.name == 'r' {
				ctx.r.texture(img, sampler)
				return
			}
		}
		sgl.texture(img, sampler)
	}

	@[inline]
	fn im_begin_quads(ctx &gg.Context) {
		$for field in gg.Context.fields {
			$if field.name == 'r' {
				ctx.r.begin_quads()
				return
			}
		}
		sgl.begin_quads()
	}

	@[inline]
	fn im_begin_triangles(ctx &gg.Context) {
		$for field in gg.Context.fields {
			$if field.name == 'r' {
				ctx.r.begin_triangles()
				return
			}
		}
		sgl.begin_triangles()
	}

	@[inline]
	fn im_begin_triangle_strip(ctx &gg.Context) {
		$for field in gg.Context.fields {
			$if field.name == 'r' {
				ctx.r.begin_triangle_strip()
				return
			}
		}
		sgl.begin_triangle_strip()
	}

	@[inline]
	fn im_end(ctx &gg.Context) {
		$for field in gg.Context.fields {
			$if field.name == 'r' {
				ctx.r.end()
				return
			}
		}
		sgl.end()
	}

	@[inline]
	fn im_c4b(ctx &gg.Context, r u8, g u8, b u8, a u8) {
		$for field in gg.Context.fields {
			$if field.name == 'r' {
				ctx.r.c4b(r, g, b, a)
				return
			}
		}
		sgl.c4b(r, g, b, a)
	}

	@[inline]
	fn im_v2f(ctx &gg.Context, x f32, y f32) {
		$for field in gg.Context.fields {
			$if field.name == 'r' {
				ctx.r.v2f(x, y)
				return
			}
		}
		sgl.v2f(x, y)
	}

	@[inline]
	fn im_v2f_t2f_c4f(ctx &gg.Context, x f32, y f32, u f32, v f32, r f32, g f32, b f32, a f32) {
		$for field in gg.Context.fields {
			$if field.name == 'r' {
				ctx.r.v2f_t2f_c4f(x, y, u, v, r, g, b, a)
				return
			}
		}
		sgl.v2f_t2f_c4f(x, y, u, v, r, g, b, a)
	}

	@[inline]
	fn im_scissor_rect(ctx &gg.Context, x int, y int, width int, height int) {
		$for field in gg.Context.fields {
			$if field.name == 'r' {
				ctx.r.scissor_rect(x, y, width, height, true)
				return
			}
		}
		sgl.scissor_rect(x, y, width, height, true)
	}
}
