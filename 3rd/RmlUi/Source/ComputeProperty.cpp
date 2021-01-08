/*
 * This source file is part of RmlUi, the HTML/CSS Interface Middleware
 *
 * For the latest information, see http://github.com/mikke89/RmlUi
 *
 * Copyright (c) 2008-2010 CodePoint Ltd, Shift Technology Ltd
 * Copyright (c) 2019 The RmlUi Team, and contributors
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 */

#include "../Include/RmlUi/Property.h"
#include "ComputeProperty.h"

namespace Rml {

const Style::ComputedValues DefaultComputedValues = Style::ComputedValues{};

static constexpr float PixelsPerInch = 96.0f;

float ComputeLength(const Property* property, float font_size, float document_font_size, float dp_ratio)
{
	RMLUI_ASSERT(property);
	
	float value = property->value.Get<float>();

	switch (property->unit)
	{
	case Property::NUMBER:
	case Property::PX:
	case Property::RAD:
		return value;

	case Property::EM:
		return value * font_size;
	case Property::REM:
		return value * document_font_size;
	case Property::DP:
		return value * dp_ratio;

	case Property::DEG:
		return Math::DegreesToRadians(value);
	default: 
		break;
	}

	// Values based on pixels-per-inch.
	if (property->unit & Property::PPI_UNIT)
	{
		float inch = value * PixelsPerInch;

		switch (property->unit)
		{
		case Property::INCH: // inch
			return inch;
		case Property::CM: // centimeter
			return inch * (1.0f / 2.54f);
		case Property::MM: // millimeter
			return inch * (1.0f / 25.4f);
		case Property::PT: // point
			return inch * (1.0f / 72.0f);
		case Property::PC: // pica
			return inch * (1.0f / 6.0f);
		default:
			break;
		}
	}

	// We're not a numeric property; return 0.
	return 0.0f;
}

float ComputeAbsoluteLength(const Property& property, float dp_ratio)
{
	RMLUI_ASSERT(property.unit & Property::ABSOLUTE_LENGTH);

	switch (property.unit)
	{
	case Property::PX:
		return property.value.Get< float >();
	case Property::DP:
		return property.value.Get< float >()* dp_ratio;
	default:
		// Values based on pixels-per-inch.
		if (property.unit & Property::PPI_UNIT)
		{
			float inch = property.value.Get< float >() * PixelsPerInch;

			switch (property.unit)
			{
			case Property::INCH: // inch
				return inch;
			case Property::CM: // centimeter
				return inch * (1.0f / 2.54f);
			case Property::MM: // millimeter
				return inch * (1.0f / 25.4f);
			case Property::PT: // point
				return inch * (1.0f / 72.0f);
			case Property::PC: // pica
				return inch * (1.0f / 6.0f);
			default:
				break;
			}
		}
	}

	RMLUI_ERROR;
	return 0.0f;
}

float ComputeAngle(const Property& property)
{
	float value = property.value.Get<float>();

	switch (property.unit)
	{
	case Property::NUMBER:
	case Property::RAD:
		return value;

	case Property::DEG:
		return Math::DegreesToRadians(value);
	default:
		break;
	}

	return 0.0f;
}

float ComputeFontsize(const Property& property, const Style::ComputedValues& values, const Style::ComputedValues* parent_values, const Style::ComputedValues* document_values, float dp_ratio)
{
	// The calculated value of the font-size property is inherited, so we need to check if this
	// is an inherited property. If so, then we return our parent's font size instead.
	if (property.unit & Property::RELATIVE_UNIT)
	{
		float multiplier = 1.0f;

		switch (property.unit)
		{
		case Property::PERCENT:
			multiplier = 0.01f;
			//-fallthrough
		case Property::EM:
			if (!parent_values)
				return 0;
			return property.value.Get< float >() * multiplier * parent_values->font_size;

		case Property::REM:
			if (!document_values)
				return 0;
			// If the current element is a document, the rem unit is relative to the default size
			if(&values == document_values)
				return property.value.Get< float >() * DefaultComputedValues.font_size;
			// Otherwise it is relative to the document font size
			return property.value.Get< float >() * document_values->font_size;
		default:
			RMLUI_ERRORMSG("A relative unit must be percentage, em or rem.");
		}
	}

	return ComputeAbsoluteLength(property, dp_ratio);
}

Style::LengthPercentage ComputeOrigin(const Property* property, float font_size, float document_font_size, float dp_ratio)
{
	using namespace Style;
	static_assert((int)OriginX::Left == (int)OriginY::Top && (int)OriginX::Center == (int)OriginY::Center && (int)OriginX::Right == (int)OriginY::Bottom, "");

	if (property->unit & Property::KEYWORD)
	{
		float percent = 0.0f;
		OriginX origin = (OriginX)property->Get<int>();
		switch (origin)
		{
		case OriginX::Left: percent = 0.0f; break;
		case OriginX::Center: percent = 50.0f; break;
		case OriginX::Right: percent = 100.f; break;
		}
		return LengthPercentage(LengthPercentage::Percentage, percent);
	}
	else if (property->unit & Property::PERCENT)
		return LengthPercentage(LengthPercentage::Percentage, property->Get<float>());

	return LengthPercentage(LengthPercentage::Length, ComputeLength(property, font_size, document_font_size, dp_ratio));
}


} // namespace Rml
