#include <Object/Quadrilateral.h>
#include <World/World.h>

Vertex* Quadrilateral::GetVertex(int idx)
{
	return &GetWorld()->vertices[vertexIdx[idx]];
}

Material* Quadrilateral::GetMaterial()
{
	return &GetWorld()->materials[materialIdx];
}

void Quadrilateral::Init()
{
	Vector3 v1 = GetVertex(1)->worldLocation - GetVertex(0)->worldLocation;
	Vector3 v2 = GetVertex(2)->worldLocation - GetVertex(0)->worldLocation;
	Vector3 v3 = GetVertex(3)->worldLocation - GetVertex(0)->worldLocation;

	float angle1 = Angle(v1, v2);
	float angle2 = Angle(v2, v3);
	float angle3 = Angle(v1, v3);

	if (angle1 + angle3 == angle2)
	{
		int temp = vertexIdx[1];
		vertexIdx[1] = vertexIdx[2];
		vertexIdx[2] = temp;
	}
	else if (angle2 + angle3 == angle1)
	{
		int temp = vertexIdx[2];
		vertexIdx[2] = vertexIdx[3];
		vertexIdx[3] = temp;
	}

	normal = Cross(v1, v2).GetNormalized();	

	if (vertexNormal)
	{
		if (Dot(normal, GetVertex(0)->worldDirection + GetVertex(1)->worldDirection + GetVertex(2)->worldDirection + GetVertex(3)->worldDirection) < 0)
		{			
			normal = -normal;
		}
	}

	distance = -Dot(GetVertex(0)->worldLocation, normal);
}

Material* Quadrilateral::GetMaterial(DeviceWorld* world)
{
	return world->materials + materialIdx;
}

Vector3 Quadrilateral::GetAlbedo(DeviceWorld* world, const Vector3& barycentricCoordinate)
{
	return (world->materials + materialIdx)->albedo;
}

bool Quadrilateral::IncludeDetect(DeviceWorld* world, Vector3& location)
{
	/*
	int vIdx1 = quadrilateral->vertexIdx[0] * 3;
	int vIdx2 = quadrilateral->vertexIdx[1] * 3;
	int vIdx3 = quadrilateral->vertexIdx[2] * 3;
	int vIdx4 = quadrilateral->vertexIdx[3] * 3;
	Vector3 vLocation1(DevVertices[vIdx1], DevVertices[vIdx1 + 1], DevVertices[vIdx1 + 2]);
	Vector3 vLocation2(DevVertices[vIdx2], DevVertices[vIdx2 + 1], DevVertices[vIdx2 + 2]);
	Vector3 vLocation3(DevVertices[vIdx3], DevVertices[vIdx3 + 1], DevVertices[vIdx3 + 2]);
	Vector3 vLocation4(DevVertices[vIdx4], DevVertices[vIdx4 + 1], DevVertices[vIdx4 + 2]);
	*/
	Vector3 vLocation1 = world->vertices[vertexIdx[0]].worldLocation;
	Vector3 vLocation2 = world->vertices[vertexIdx[1]].worldLocation;
	Vector3 vLocation3 = world->vertices[vertexIdx[2]].worldLocation;
	Vector3 vLocation4 = world->vertices[vertexIdx[3]].worldLocation;

	Vector3 pa = vLocation1 - location;
	Vector3 pb = vLocation2 - location;
	Vector3 pc = vLocation3 - location;
	Vector3 pd = vLocation4 - location;

	float angle1 = Angle(pa, pb);
	float angle2 = Angle(pb, pc);
	float angle3 = Angle(pc, pd);
	float angle4 = Angle(pd, pa);

	if (abs(angle1 + angle2 + angle3 + angle4 - PI * 2) > 1.0e-3)
	{
		return false;
	}
	return true;
}

bool Quadrilateral::HitDetect(DeviceWorld* world, Ray* ray, RayHitResult* hitResult)
{
	return false;
	Vector3 n = normal;
	float in = Dot(ray->direction, n);
	float d = distance;
	if (in == 0.0)
	{
		return false;
	}
	if (in > 0.0)
	{
		if ((world->materials + materialIdx)->backVisible)
		{
			n = -n;
			in = -in;
			d = -d;
		}
		else
		{
			return false;
		}
	}
	
	float l = Dot(ray->location, n) + d;
	float distance = -l / in;
	if (distance < MIN_DETECT_DISTANCE || distance > hitResult->distance)
	{
		return false;
	}

	Vector3 location = ray->location + ray->direction * distance;
	Vector3 coordinate;

	if (!IncludeDetect(world, location))
	{
		return false;
	}
	hitResult->isHit = true;
	hitResult->normal = n;
	hitResult->location = location;
	hitResult->distance = distance;
	hitResult->material = world->materials + materialIdx;
	hitResult->color = GetAlbedo(world, coordinate);

	return true;
}
