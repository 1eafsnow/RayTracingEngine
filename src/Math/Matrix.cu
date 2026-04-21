#include "Matrix.h"

std::ostream& operator<<(std::ostream& os, const Matrix3F& v)
{
	os << '(' << v.elements[0] << ', ' << v.elements[1] << ', ' << v.elements[2] << ', '
		<< v.elements[3] << ', ' << v.elements[4] << ', ' << v.elements[5] << ', '
		<< v.elements[6] << ', ' << v.elements[7] << ', ' << v.elements[8] << ')';
	return os;
}

std::ostream& operator<<(std::ostream& os, const Matrix4F& v)
{
	os << '(' << v.elements[0] << ', ' << v.elements[1] << ', ' << v.elements[2] << ', ' << v.elements[3] << ', '
		<< v.elements[4] << ', ' << v.elements[5] << ', ' << v.elements[6] << ', ' << v.elements[7] << ', '
		<< v.elements[8] << ', ' << v.elements[9] << ', ' << v.elements[10] << v.elements[11] << ', '
		<< v.elements[12] << ', ' << v.elements[13] << ', ' << v.elements[14] << v.elements[15] << ')';
	return os;
}