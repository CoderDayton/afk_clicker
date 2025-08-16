--[[
StyleGuide.luau - Optimized with cached sequences and validation
]]

-- Types (unchanged but cleaner)
export type ColorSet = {
	SURFACE_Primary: Color3,
	SURFACE_Elevation1: Color3,
	SURFACE_Elevation2: Color3,
	TEXT_Primary: Color3,
	TEXT_Secondary: Color3,
	TEXT_Inverse: Color3,
	ACCENT_Primary: Color3,
	ACCENT_Secondary: Color3,
	STATE_Success: Color3,
	STATE_Warning: Color3,
	STATE_Danger: Color3,
	BORDER_Subtle: Color3,
	BORDER_Strong: Color3,
	FOCUS: Color3,
}

export type Gradients = {
	CTA: { Colors: ColorSequence, Rotation: number },
	PanelNeutral: { Colors: ColorSequence, Rotation: number },
	SheenBand: NumberSequence,
	Purple: { Colors: ColorSequence, Rotation: number },
	Red: { Colors: ColorSequence, Rotation: number },
	Grey: { Colors: ColorSequence, Rotation: number },
	Green: { Colors: ColorSequence, Rotation: number },
	Tan: { Colors: ColorSequence, Rotation: number },
	Orange: { Colors: ColorSequence, Rotation: number },
	Gold: { Colors: ColorSequence, Rotation: number },
}

local StyleGuide = {}

-- Font helper
local function font(id: string, weight: Enum.FontWeight): Font
	return Font.new(id, weight, Enum.FontStyle.Normal)
end

-- Colors (unchanged)
StyleGuide.Colors = {
	SURFACE_Primary = Color3.fromRGB(18, 18, 20),
	SURFACE_Elevation1 = Color3.fromRGB(28, 28, 32),
	SURFACE_Elevation2 = Color3.fromRGB(36, 36, 42),
	TEXT_Primary = Color3.fromRGB(235, 239, 245),
	TEXT_Secondary = Color3.fromRGB(178, 184, 196),
	TEXT_Inverse = Color3.fromRGB(0, 0, 0),
	ACCENT_Primary = Color3.fromRGB(0, 229, 255),
	ACCENT_Secondary = Color3.fromRGB(0, 204, 170),
	STATE_Success = Color3.fromRGB(64, 201, 112),
	STATE_Warning = Color3.fromRGB(255, 187, 0),
	STATE_Danger = Color3.fromRGB(232, 80, 91),
	BORDER_Subtle = Color3.fromRGB(40, 40, 48),
	BORDER_Strong = Color3.fromRGB(64, 64, 76),
	FOCUS = Color3.fromRGB(0, 200, 255),
} :: ColorSet

-- Glows (unchanged)
StyleGuide.Glow = {
	CTA = Color3.fromRGB(0, 200, 255),
	Purple = Color3.fromRGB(128, 64, 255),
	Red = Color3.fromRGB(255, 96, 72),
	Grey = Color3.fromRGB(84, 88, 96),
	Green = Color3.fromRGB(16, 185, 129),
	Tan = Color3.fromRGB(199, 167, 120),
	Orange = Color3.fromRGB(255, 140, 20),
	Gold = Color3.fromRGB(255, 210, 80),
}

-- Typography (unchanged)
StyleGuide.Typography = {
	Header = font("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.ExtraBold),
	Body = font("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium),
	Regular = font("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Regular),
	Sizes = { XS = 12, S = 14, M = 16, L = 20, XL = 24, XXL = 32 },
}

-- Spacing (unchanged)
StyleGuide.Spacing = {
	Padding = { XS = 6, S = 10, M = 14, L = 18, XL = 24 },
	Gaps = { XS = 4, S = 8, M = 12, L = 16, XL = 24 },
	Radius = { XS = 6, S = 10, M = 14, L = 20, Pill = 999 },
	TapTargetMin = 56,
}

-- Scale helpers
local REF_X, REF_Y = 1280, 720
StyleGuide.ScaleFuncs = {
	X = function(px: number)
		return px / REF_X
	end,
	Y = function(py: number)
		return py / REF_Y
	end,
}
StyleGuide.Scale = { ButtonHeight = 56, HeaderHeight = 64 }

-- Shadows
StyleGuide.Shadow = {
	SoftShadow = { Blur = 24, Size = 0, Opacity = 0.25 },
	SoftShadowPresets = {
		PanelInside = { Location = "Inside", SizeScale = 1.00, Opacity = 0.20, Color = Color3.fromRGB(0, 0, 0) },
		PanelOutside = { Location = "Outside", SizeScale = 1.20, Opacity = 0.30, Color = Color3.fromRGB(0, 0, 0) },
		CTA = { Location = "Outside", SizeScale = 1.30, Opacity = 0.40, Color = Color3.fromRGB(0, 200, 255) },
		Purple = { Location = "Outside", SizeScale = 1.25, Opacity = 0.36, Color = Color3.fromRGB(128, 64, 255) },
		Red = { Location = "Outside", SizeScale = 1.25, Opacity = 0.36, Color = Color3.fromRGB(255, 96, 72) },
		Grey = { Location = "Outside", SizeScale = 1.20, Opacity = 0.30, Color = Color3.fromRGB(84, 88, 96) },
		Green = { Location = "Outside", SizeScale = 1.25, Opacity = 0.34, Color = Color3.fromRGB(16, 185, 129) },
		Tan = { Location = "Outside", SizeScale = 1.20, Opacity = 0.30, Color = Color3.fromRGB(199, 167, 120) },
		Orange = { Location = "Outside", SizeScale = 1.25, Opacity = 0.36, Color = Color3.fromRGB(255, 140, 20) },
		Gold = { Location = "Outside", SizeScale = 1.25, Opacity = 0.36, Color = Color3.fromRGB(255, 210, 80) },
		CyanGlow = { Location = "Outside", SizeScale = 1.30, Opacity = 0.42, Color = Color3.fromRGB(0, 225, 255) },
		MagentaGlow = { Location = "Outside", SizeScale = 1.28, Opacity = 0.40, Color = Color3.fromRGB(247, 39, 152) }, -- #F72798[12]
		ElectricBlue = { Location = "Outside", SizeScale = 1.26, Opacity = 0.38, Color = Color3.fromRGB(0, 120, 255) },
		Lime = { Location = "Outside", SizeScale = 1.24, Opacity = 0.36, Color = Color3.fromRGB(150, 255, 60) },
		Rose = { Location = "Outside", SizeScale = 1.22, Opacity = 0.34, Color = Color3.fromRGB(255, 90, 130) },
		Amber = { Location = "Outside", SizeScale = 1.24, Opacity = 0.35, Color = Color3.fromRGB(255, 185, 30) },
		TealDeep = { Location = "Outside", SizeScale = 1.18, Opacity = 0.28, Color = Color3.fromRGB(14, 120, 120) },
		Indigo = { Location = "Outside", SizeScale = 1.20, Opacity = 0.30, Color = Color3.fromRGB(70, 80, 160) },
		BlackSoft = { Location = "Outside", SizeScale = 1.18, Opacity = 0.26, Color = Color3.fromRGB(0, 0, 0) },
		WhiteLift = { Location = "Inside", SizeScale = 1.10, Opacity = 0.20, Color = Color3.fromRGB(255, 255, 255) },
		OutlineHigh = { Location = "Outside", SizeScale = 2.0, Opacity = 0.65, Color = Color3.fromRGB(0, 0, 0) }, -- for focus ring depth[10][16][13]
		Danger = { Location = "Outside", SizeScale = 1.16, Opacity = 0.34, Color = Color3.fromRGB(230, 40, 30) },
	},
}

-- OPTIMIZED: Pre-built gradient sequences (cached for performance)
StyleGuide.Gradients = {
	CTA = {
		Colors = ColorSequence.new({
			ColorSequenceKeypoint.new(0.00, Color3.fromRGB(0, 229, 255)),
			ColorSequenceKeypoint.new(0.52, Color3.fromRGB(0, 149, 255)),
			ColorSequenceKeypoint.new(1.00, Color3.fromRGB(10, 80, 255)),
		}),
		Rotation = 30,
	},
	PanelNeutral = {
		Colors = ColorSequence.new({
			ColorSequenceKeypoint.new(0.00, Color3.fromRGB(16, 140, 140)),
			ColorSequenceKeypoint.new(1.00, Color3.fromRGB(54, 62, 78)),
		}),
		Rotation = 90,
	},
	SheenBand = NumberSequence.new({
		NumberSequenceKeypoint.new(0.00, 1),
		NumberSequenceKeypoint.new(0.45, 1),
		NumberSequenceKeypoint.new(0.50, 0),
		NumberSequenceKeypoint.new(0.55, 1),
		NumberSequenceKeypoint.new(1.00, 1),
	}),
	Purple = {
		Colors = ColorSequence.new({
			ColorSequenceKeypoint.new(0.00, Color3.fromRGB(168, 92, 255)),
			ColorSequenceKeypoint.new(0.55, Color3.fromRGB(122, 60, 255)),
			ColorSequenceKeypoint.new(1.00, Color3.fromRGB(79, 70, 229)),
		}),
		Rotation = 35,
	},
	Red = {
		Colors = ColorSequence.new({
			ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 65, 108)),
			ColorSequenceKeypoint.new(0.55, Color3.fromRGB(255, 75, 43)),
			ColorSequenceKeypoint.new(1.00, Color3.fromRGB(200, 30, 30)),
		}),
		Rotation = 25,
	},
	Grey = {
		Colors = ColorSequence.new({
			ColorSequenceKeypoint.new(0.00, Color3.fromRGB(84, 88, 96)),
			ColorSequenceKeypoint.new(0.55, Color3.fromRGB(66, 70, 78)),
			ColorSequenceKeypoint.new(1.00, Color3.fromRGB(44, 48, 54)),
		}),
		Rotation = 0,
	},
	Green = {
		Colors = ColorSequence.new({
			ColorSequenceKeypoint.new(0.00, Color3.fromRGB(52, 211, 153)),
			ColorSequenceKeypoint.new(0.55, Color3.fromRGB(16, 185, 129)),
			ColorSequenceKeypoint.new(1.00, Color3.fromRGB(5, 150, 105)),
		}),
		Rotation = 30,
	},
	Tan = {
		Colors = ColorSequence.new({
			ColorSequenceKeypoint.new(0.00, Color3.fromRGB(214, 191, 165)),
			ColorSequenceKeypoint.new(0.55, Color3.fromRGB(191, 165, 131)),
			ColorSequenceKeypoint.new(1.00, Color3.fromRGB(160, 127, 90)),
		}),
		Rotation = 30,
	},
	Orange = {
		Colors = ColorSequence.new({
			ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 176, 32)),
			ColorSequenceKeypoint.new(0.55, Color3.fromRGB(255, 138, 0)),
			ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 94, 0)),
		}),
		Rotation = 25,
	},
	Gold = {
		Colors = ColorSequence.new({
			ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 240, 170)),
			ColorSequenceKeypoint.new(0.50, Color3.fromRGB(255, 201, 77)),
			ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 179, 0)),
		}),
		Rotation = 20,
	},
	-- Neon Cyan → Magenta “CyberPulse”
	CyberPulse = {
		Colors = ColorSequence.new({
			ColorSequenceKeypoint.new(0.00, Color3.fromRGB(0, 229, 255)),
			ColorSequenceKeypoint.new(0.50, Color3.fromRGB(120, 0, 255)),
			ColorSequenceKeypoint.new(1.00, Color3.fromRGB(247, 39, 152)),
		}),
		Rotation = 18,
	},

	-- Electric Blue → Violet “HyperDrive”
	HyperDrive = {
		Colors = ColorSequence.new({
			ColorSequenceKeypoint.new(0.00, Color3.fromRGB(0, 149, 255)),
			ColorSequenceKeypoint.new(0.60, Color3.fromRGB(79, 70, 229)),
			ColorSequenceKeypoint.new(1.00, Color3.fromRGB(128, 64, 255)),
		}),
		Rotation = 40,
	},

	-- Lime → Amber “Voltage”
	Voltage = {
		Colors = ColorSequence.new({
			ColorSequenceKeypoint.new(0.00, Color3.fromRGB(150, 255, 60)),
			ColorSequenceKeypoint.new(0.55, Color3.fromRGB(255, 210, 80)),
			ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 138, 0)),
		}),
		Rotation = 28,
	},

	-- Rose → Orange → Gold “HeatWave”
	HeatWave = {
		Colors = ColorSequence.new({
			ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 90, 130)),
			ColorSequenceKeypoint.new(0.50, Color3.fromRGB(255, 94, 0)),
			ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 179, 0)),
		}),
		Rotation = 22,
	},

	-- Teal → Indigo “DeepSea”
	DeepSea = {
		Colors = ColorSequence.new({
			ColorSequenceKeypoint.new(0.00, Color3.fromRGB(14, 120, 120)),
			ColorSequenceKeypoint.new(0.60, Color3.fromRGB(70, 80, 160)),
			ColorSequenceKeypoint.new(1.00, Color3.fromRGB(34, 38, 46)),
		}),
		Rotation = 95,
	},

	-- Silver Sheen (cool metallic)
	SilverSheen = {
		Colors = ColorSequence.new({
			ColorSequenceKeypoint.new(0.00, Color3.fromRGB(245, 248, 255)),
			ColorSequenceKeypoint.new(0.50, Color3.fromRGB(200, 210, 225)),
			ColorSequenceKeypoint.new(1.00, Color3.fromRGB(160, 170, 185)),
		}),
		Rotation = 12,
	},

	-- Toxic Green → Cyan “Biohazard”
	Biohazard = {
		Colors = ColorSequence.new({
			ColorSequenceKeypoint.new(0.00, Color3.fromRGB(0, 255, 170)),
			ColorSequenceKeypoint.new(0.48, Color3.fromRGB(0, 225, 255)),
			ColorSequenceKeypoint.new(1.00, Color3.fromRGB(0, 149, 255)),
		}),
		Rotation = 33,
	},

	-- Sunset Purple → Rose “Nectar”
	Nectar = {
		Colors = ColorSequence.new({
			ColorSequenceKeypoint.new(0.00, Color3.fromRGB(168, 92, 255)),
			ColorSequenceKeypoint.new(0.55, Color3.fromRGB(247, 39, 152)),
			ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 140, 20)),
		}),
		Rotation = 35,
	},

	-- Gunmetal → Blue “CarbonIce”
	CarbonIce = {
		Colors = ColorSequence.new({
			ColorSequenceKeypoint.new(0.00, Color3.fromRGB(44, 48, 54)),
			ColorSequenceKeypoint.new(0.60, Color3.fromRGB(66, 70, 78)),
			ColorSequenceKeypoint.new(1.00, Color3.fromRGB(0, 120, 255)),
		}),
		Rotation = 0,
	},

	-- Sand → Gold “Gilded”
	Gilded = {
		Colors = ColorSequence.new({
			ColorSequenceKeypoint.new(0.00, Color3.fromRGB(214, 191, 165)),
			ColorSequenceKeypoint.new(0.50, Color3.fromRGB(255, 201, 77)),
			ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 179, 0)),
		}),
		Rotation = 16,
	},

	-- Dark panel glow (subtle UI background)
	AbyssGlow = {
		Colors = ColorSequence.new({
			ColorSequenceKeypoint.new(0.00, Color3.fromRGB(16, 18, 22)),
			ColorSequenceKeypoint.new(0.55, Color3.fromRGB(24, 28, 34)),
			ColorSequenceKeypoint.new(1.00, Color3.fromRGB(30, 36, 44)),
		}),
		Rotation = 90,
	},

	-- Rainbow loop (clean banding-conscious spacing)
	Rainbow = {
		Colors = ColorSequence.new({
			ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 0, 85)),
			ColorSequenceKeypoint.new(0.20, Color3.fromRGB(255, 140, 0)),
			ColorSequenceKeypoint.new(0.40, Color3.fromRGB(255, 255, 0)),
			ColorSequenceKeypoint.new(0.60, Color3.fromRGB(0, 255, 120)),
			ColorSequenceKeypoint.new(0.80, Color3.fromRGB(0, 149, 255)),
			ColorSequenceKeypoint.new(1.00, Color3.fromRGB(170, 0, 255)),
		}),
		Rotation = 0,
	},

	-- Hot Magenta → Blue “CandyGlass”
	CandyGlass = {
		Colors = ColorSequence.new({
			ColorSequenceKeypoint.new(0.00, Color3.fromRGB(247, 39, 152)),
			ColorSequenceKeypoint.new(0.55, Color3.fromRGB(128, 64, 255)),
			ColorSequenceKeypoint.new(1.00, Color3.fromRGB(0, 149, 255)),
		}),
		Rotation = 24,
	},

	-- Emerald → Teal “Seaglass”
	Seaglass = {
		Colors = ColorSequence.new({
			ColorSequenceKeypoint.new(0.00, Color3.fromRGB(52, 211, 153)),
			ColorSequenceKeypoint.new(0.55, Color3.fromRGB(16, 185, 129)),
			ColorSequenceKeypoint.new(1.00, Color3.fromRGB(14, 120, 120)),
		}),
		Rotation = 30,
	},

	-- Peach → Gold “HoneyDrip”
	HoneyDrip = {
		Colors = ColorSequence.new({
			ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 176, 120)),
			ColorSequenceKeypoint.new(0.55, Color3.fromRGB(255, 201, 77)),
			ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 179, 0)),
		}),
		Rotation = 12,
	},

	-- Frosted Blue → White “Glacier”
	Glacier = {
		Colors = ColorSequence.new({
			ColorSequenceKeypoint.new(0.00, Color3.fromRGB(0, 149, 255)),
			ColorSequenceKeypoint.new(0.55, Color3.fromRGB(120, 190, 255)),
			ColorSequenceKeypoint.new(1.00, Color3.fromRGB(245, 248, 255)),
		}),
		Rotation = 75,
	},

	-- Infrared Danger “IRis”
	IRis = {
		Colors = ColorSequence.new({
			ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 65, 108)),
			ColorSequenceKeypoint.new(0.50, Color3.fromRGB(255, 75, 43)),
			ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 210, 80)),
		}),
		Rotation = 18,
	},

	-- Midnight Blue → Cyan edge “EdgeLight”
	EdgeLight = {
		Colors = ColorSequence.new({
			ColorSequenceKeypoint.new(0.00, Color3.fromRGB(10, 80, 255)),
			ColorSequenceKeypoint.new(0.60, Color3.fromRGB(0, 149, 255)),
			ColorSequenceKeypoint.new(1.00, Color3.fromRGB(0, 229, 255)),
		}),
		Rotation = 8,
	},

	-- Purple haze overlay “Nebula”
	Nebula = {
		Colors = ColorSequence.new({
			ColorSequenceKeypoint.new(0.00, Color3.fromRGB(90, 70, 200)),
			ColorSequenceKeypoint.new(0.55, Color3.fromRGB(128, 64, 255)),
			ColorSequenceKeypoint.new(1.00, Color3.fromRGB(247, 39, 152)),
		}),
		Rotation = 42,
	},
} :: Gradients

-- Strokes
StyleGuide.Stroke = {
	Subtle = { Thickness = 1, Transparency = 0.35, Color = Color3.fromRGB(255, 255, 255) },
	Strong = { Thickness = 1, Transparency = 0.20, Color = Color3.fromRGB(0, 0, 0) },
	Focus = { Thickness = 2, Transparency = 0.0, Color = StyleGuide.Colors.FOCUS },
	Presets = {
		CTA = { Thickness = 1, Transparency = 0.20, Color = Color3.fromRGB(255, 255, 255) },
		Purple = { Thickness = 1, Transparency = 0.20, Color = Color3.fromRGB(255, 255, 255) },
		Red = { Thickness = 1, Transparency = 0.18, Color = Color3.fromRGB(255, 255, 255) },
		Grey = { Thickness = 1, Transparency = 0.30, Color = Color3.fromRGB(255, 255, 255) },
		Green = { Thickness = 1, Transparency = 0.20, Color = Color3.fromRGB(255, 255, 255) },
		Tan = { Thickness = 1, Transparency = 0.25, Color = Color3.fromRGB(0, 0, 0) },
		Orange = { Thickness = 1, Transparency = 0.22, Color = Color3.fromRGB(0, 0, 0) },
		Gold = { Thickness = 1, Transparency = 0.22, Color = Color3.fromRGB(0, 0, 0) },
	},
}

return table.freeze(StyleGuide)
