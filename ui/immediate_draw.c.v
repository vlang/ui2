// vfmt off
// Immediate-mode draws go through sokol-gl directly so they compile on the
// V 0.5.2 toolchain CI pins (whose gg predates render.Context) as well as on
// newer V (whose sokol-gl API is unchanged). The alpha pipeline below mirrors
// the blend state gg itself used to install for these draws.
@[has_globals]
module ui2

$if (android || linux || freebsd || openbsd || netbsd || dragonfly || solaris || ((macos || windows) && ui2_custom_rendering ?)) && !ui2_headless ? {
	import sokol.gfx
	import sokol.sgl

	__global im_draw_ready = false
	__global im_alpha_pipe = sgl.Pipeline{}

	// im_draw_setup prepares sokol-gl for the immediate backend. Newer gg
	// drives its own pure-V renderer and no longer sets sgl up; 0.5.2-era gg
	// did it internally during context creation. Called once from on_init, so
	// it runs a single time on either toolchain.
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
		if im_draw_ready && im_alpha_pipe.id != 0 {
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
		im_draw_ready = true
		return im_alpha_pipe
	}
}
