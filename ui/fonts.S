/* OFL fonts compiled into the binary (see third_party/README.md); Mach-O, assembled with -I<third_party/fonts> */
	.section __TEXT,__const
	.p2align 4
	.globl _eiii_font_regular
	.private_extern _eiii_font_regular
	.globl _eiii_font_regular_end
	.private_extern _eiii_font_regular_end
_eiii_font_regular:
	.incbin "NotoSans-CondensedMedium.ttf"
_eiii_font_regular_end:
	.p2align 4
	.globl _eiii_font_bold
	.private_extern _eiii_font_bold
	.globl _eiii_font_bold_end
	.private_extern _eiii_font_bold_end
_eiii_font_bold:
	.incbin "NotoSans-CondensedSemiBold.ttf"
_eiii_font_bold_end:
	.p2align 4
	.globl _eiii_font_narrow
	.private_extern _eiii_font_narrow
	.globl _eiii_font_narrow_end
	.private_extern _eiii_font_narrow_end
_eiii_font_narrow:
	.incbin "ArchivoNarrow-wght.ttf"
_eiii_font_narrow_end:
