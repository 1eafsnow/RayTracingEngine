#include <Math/Math.h>

__host__ float Random()
{
	float r = (float)rand() / RAND_MAX;
	return r;
}

__host__ float RandomLeftOpen()
{
	float r = (float)(rand() + 1) / (RAND_MAX + 1);
	return r;
}

__host__ float RandomRightOpen()
{
	float r = (float)rand() / (RAND_MAX + 1);
	return r;
}

__host__ float RandomOpen()
{
	float r = (float)(rand() + 1) / (RAND_MAX + 2);
	return r;
}

__host__ float Random(const float& min, const float& max, const bool& lInterval, const bool& rInterval)
{
	float r = ((float)rand() / RAND_MAX) / (max - min) + min;
	return r;
}

__global__ void InitRandStates(curandStateXORWOW_t* states, unsigned long long seed)
{
	int idx = blockDim.x * blockIdx.x + threadIdx.x;
	curand_init(seed, idx, 0, states + idx);
}

__device__ float DevRand(curandStateXORWOW_t* state)
{
	//int idx = blockDim.x * blockIdx.x + threadIdx.x;
	return curand_uniform(state);
}

__device__ float DevRandClose(curandStateXORWOW_t* state)
{
	return DevRand(state);
}

__device__ float DevRandOpen(curandStateXORWOW_t* state)
{
	return DevRand(state);
}

__host__ __device__ int Max(const int& a, const int& b)
{
	return (a > b) ? a : b;
}

__host__ __device__ int Min(const int& a, const int& b)
{
	return (a < b) ? a : b;
}

__host__ __device__ float Max(const float& a, const float& b)
{
	return (a > b) ? a : b;
}

__host__ __device__ float Min(const float& a, const float& b)
{
	return (a < b) ? a : b;
}

__host__ __device__ float Clamp(const float& x, const float& min, const float& max)
{
	if (x < min)
	{
		return min;
	}
	else if (x > max)
	{
		return max;
	}
	return x;
}

__host__ __device__ void Normalize(Vector3& v)
{
	float length = sqrt(v.x * v.x + v.y * v.y + v.z * v.z);
	v.x = v.x / length;
	v.y = v.y / length;
	v.z = v.z / length;
}

__host__ __device__ float Dot(const Vector2& v1, const Vector2& v2)
{
	return v1.x * v2.x + v1.y * v2.y;
}

__host__ __device__ float Dot(const Vector3& v1, const Vector3& v2)
{
	return v1.x * v2.x + v1.y * v2.y + v1.z * v2.z;
}

__host__ __device__ Vector3 Cross(const Vector3& v1, const Vector3& v2)
{
	return Vector3(v1.y * v2.z - v1.z * v2.y, v1.z * v2.x - v1.x * v2.z, v1.x * v2.y - v1.y * v2.x);
}

__host__ __device__ Quaternion Cross(const Quaternion& q1, const Quaternion& q2)
{
	Vector3 q1u(q1.x, q1.y, q1.z);
	Vector3 q2u(q2.x, q2.y, q2.z);
	Vector3 u = q2u * q1.w + q1u * q2.w + Cross(q1u, q2u);
	float w = q1.w * q2.w - Dot(q1u, q2u);
	return Quaternion(u, w);
}

__host__ __device__ Vector3 Matmul(const Matrix3& m, const Vector3& v)
{
	return Vector3(m.elements[0] * v.x + m.elements[1] * v.y + m.elements[2] * v.z,
		m.elements[3] * v.x + m.elements[4] * v.y + m.elements[5] * v.z,
		m.elements[6] * v.x + m.elements[7] * v.y + m.elements[8] * v.z);
}

__host__ __device__ Vector4 Matmul(const Matrix4& m, const Vector4& v)
{
	return Vector4(m.elements[0] * v.x + m.elements[1] * v.y + m.elements[2] * v.z + m.elements[3] * v.w,
		m.elements[4] * v.x + m.elements[5] * v.y + m.elements[6] * v.z + m.elements[7] * v.w,
		m.elements[8] * v.x + m.elements[9] * v.y + m.elements[10] * v.z + m.elements[11] * v.w,
		m.elements[12] * v.x + m.elements[13] * v.y + m.elements[14] * v.z + m.elements[15] * v.w);
}

__host__ __device__ Vector3 Matmul(const Matrix4& m, const Vector3& v)
{
	float w = m.elements[12] * v.x + m.elements[13] * v.y + m.elements[14] * v.z + m.elements[15];
	return Vector3(m.elements[0] * v.x + m.elements[1] * v.y + m.elements[2] * v.z + m.elements[3],
		m.elements[4] * v.x + m.elements[5] * v.y + m.elements[6] * v.z + m.elements[7],
		m.elements[8] * v.x + m.elements[9] * v.y + m.elements[10] * v.z + m.elements[11]) / w;
}

__host__ __device__ Matrix3 Matmul(Matrix3 l, Matrix3 r)
{
	Matrix3 result;
	for (int i = 0; i < 3; i++)
	{
		for (int j = 0; j < 3; j++)
		{
			for (int k = 0; k < 3; k++)
			{
				result[i][j] += l[i][k] * r[k][j];
			}
		}
	}
	return result;
}

__host__ __device__ Matrix4 Matmul(Matrix4 l, Matrix4 r)
{
	Matrix4 result;
	for (int i = 0; i < 4; i++)
	{
		for (int j = 0; j < 4; j++)
		{
			for (int k = 0; k < 4; k++)
			{
				result[i][j] += l[i][k] * r[k][j];
			}
		}
	}
	return result;
}

__host__ __device__ Matrix4 RotateMatrixToTransform(Matrix3& m)
{
	return  Matrix4(m[0][0], m[0][1], m[0][2], 0,
		m[1][0], m[1][1], m[1][2], 0,
		m[2][0], m[2][1], m[2][2], 0,
		0, 0, 0, 1);
}

__host__ __device__ Matrix3 TransformToRotateMatrix(Matrix4& m)
{
	return Matrix3(m[0][0], m[0][1], m[0][2],
		m[1][0], m[1][1], m[1][2],
		m[2][0], m[2][1], m[2][2]);
}

__host__ __device__ float Angle(Vector3& v1, Vector3& v2)
{
	float angle = acos(Dot(v1, v2) / (v1.Length() * v2.Length()));
	return angle < PI ? angle : PI * 2 - angle;
}

__host__ __device__ float Angle(Vector2& v1, Vector2& v2)
{
	float angle = acos(Dot(v1, v2) / (v1.Length() * v2.Length()));
	return angle < PI ? angle : PI * 2 - angle;
}

__device__ Vector3 Reflect(Vector3 n, Vector3 i)
{
	return (n * (Dot(n, i)) * 2 - i).GetNormalized();
}

__device__ Vector3 WeightedSampleRandom(curandStateXORWOW_t* state, const Vector3& normal)
{
	Vector3 w = normal.GetNormalized();
	Vector3 vup = fabs(w.x) > 0.9 ? Vector3(0, 1, 0) : Vector3(1, 0, 0);
	Vector3 v = Cross(vup, w).GetNormalized();
	Vector3 u = Cross(w, v).GetNormalized();

	float phi = PI * 2 * DevRandClose(state);
	float r = DevRandOpen(state);
	float x = cos(phi) * sqrt(r);
	float y = sin(phi) * sqrt(r);
	float z = sqrt(1 - r);

	return u * x + v * y + w * z;
}

__device__ Vector3 WeightedSampleCosine(curandStateXORWOW_t* state, const Vector3& normal)
{
	Vector3 w = normal.GetNormalized();
	Vector3 vup = fabs(w.x) > 0.9 ? Vector3(0, 1, 0) : Vector3(1, 0, 0);
	Vector3 v = Cross(vup, w).GetNormalized();
	Vector3 u = Cross(w, v).GetNormalized();
	
	float phi = PI * 2 * DevRandClose(state);
	float r = DevRandOpen(state);
	float x = cos(phi) * r;
	float y = sin(phi) * r;
	float z = sqrt(1 - r * r);

	return u * x + v * y + w * z;
}

__device__ Vector3 WeightedSampleGGX(curandStateXORWOW_t* state, const Vector3& normal, const float& roughness)
{
	Vector3 w = normal.GetNormalized();
	Vector3 vup = fabs(w.x) > 0.9 ? Vector3(0, 1, 0) : Vector3(1, 0, 0);
	Vector3 v = Cross(vup, w).GetNormalized();
	Vector3 u = Cross(w, v).GetNormalized();

	float r = DevRandOpen(state);

	float a2 = roughness * roughness;
	float phi = PI * 2 * DevRandClose(state);
	float cosTheta = sqrt((1 - r) / (r * (a2 - 1) + 1));
	float sinTheta = sqrt(1 - cosTheta * cosTheta);
	float x = sinTheta * cos(phi);
	float y = sinTheta * sin(phi);
	float z = cosTheta;

	return u * x + v * y + w * z;
}

__device__ Vector3 WeightedSampleSphereLight(curandStateXORWOW_t* state, const Vector3& location, const Vector3& lightLocation, const float& lightRadius)
{	
	Vector3 w = (lightLocation - location).GetNormalized();
	Vector3 vup = fabs(w.x) > 0.9 ? Vector3(0, 1, 0) : Vector3(1, 0, 0);
	Vector3 v = Cross(vup, w).GetNormalized();
	Vector3 u = Cross(w, v).GetNormalized();
	
	float r = DevRandClose(state);
	float dist = (lightLocation - location).Length();
	float cosTheta = 1 - r + r * sqrt(1 - pow(lightRadius / dist, 2));
	float sinTheta = sqrt(1 - cosTheta * cosTheta);
	float phi = PI * 2 * DevRandClose(state);
	
	float x = sinTheta * cos(phi);
	float y = sinTheta * sin(phi);
	float z = cosTheta;

	float cc = cos(phi);
	float tt = 1.2;

	return u * x + v * y + w * z;	
}

__device__ float SchlickFresnel(const float& n1, const float& n2, const Vector3& n, const Vector3& i)
{
	float dn = (n1 - n2) / (n1 + n2);
	float r0 = dn * dn;
	float c = 1 - Dot(i, n);
	return r0 + (1 - r0) * c * c * c * c * c;
}

__device__ float NDF_GGX(const Vector3& n, const Vector3& h, const float& a)
{
	float a2 = a * a;
	float nh = Dot(n, h);
	float d = (nh * a2 - nh) * nh + 1;	// 2 mad
	return a2 / (PI * d * d);
}

__device__ float GF_SchlickGGX(const Vector3& n, const Vector3& i, const Vector3& r, const float& roughness)
{
	//float a = pow((roughness + 1) / 2, 2);
	//float k = a / 2;
	float k = pow(roughness + 1, 2) / 8;
	float g1 = Dot(n, i) / (Dot(n, i) * (1 - k) + k);
	float g2 = Dot(n, r) / (Dot(n, r) * (1 - k) + k);
	return g1 * g2;
}

__device__ float GF_SmithJointGGX(const Vector3& n, const Vector3& i, const Vector3& r, const float& roughness)
{
	float a = roughness * roughness;
	float NoL = Dot(n, i);
	float NoV = Dot(n, r);
	float Vis_SmithV = NoL * (NoV * (1 - a) + a);
	float Vis_SmithL = NoV * (NoL * (1 - a) + a);
	float g = 0.5 / (Vis_SmithV + Vis_SmithL);
	return g;
}

__device__ Vector3 AcesFilm(Vector3 color)
{
	float max = color.x;
	if (color.y > max)
	{
		max = color.y;
	}
	if (color.z > max)
	{
		max = color.z;
	}
	if (max > 1.0)
	{
		color = color / max;
	}

	float a = 2.51f;
	float b = 0.03f;
	float c = 2.43f;
	float d = 0.59f;
	float e = 0.14f;

	float x = Clamp((color.x * (a * color.x + b)) / (color.x * (c * color.x + d) + e), 0.0, 1.0);
	float y = Clamp((color.y * (a * color.y + b)) / (color.y * (c * color.y + d) + e), 0.0, 1.0);
	float z = Clamp((color.z * (a * color.z + b)) / (color.z * (c * color.z + d) + e), 0.0, 1.0);
	return Vector3(x, y, z);
}