#include "Vector.h"

std::ostream& operator<<(std::ostream& os, const Vector3& v)
{
	os << '(' << v.x << ', ' << v.y << ', ' << v.y << ')';
	return os;
}

std::ostream& operator<<(std::ostream& os, const Vector4& v)
{
	os << '(' << v.x << ', ' << v.y << ', ' << v.y << ', ' << v.w << ')';
	return os;
}