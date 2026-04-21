#include <Object/Triangle.h>
#include <World/World.h>

Vertex* Triangle::GetVertex(int idx)
{
	return GetWorld()->GetVertex(vertexIdx[idx]);
}

Normal* Triangle::GetVertexNormal(int idx)
{
	//return GetWorld()->GetNormal(normalIdx[idx]);
	return nullptr;
}

Material* Triangle::GetMaterial()
{
	return &GetWorld()->materials[materialIdx];
}

void Triangle::Init()
{
	Vector3 v1 = GetVertex(1)->worldLocation - GetVertex(0)->worldLocation;
	Vector3 v2 = GetVertex(2)->worldLocation - GetVertex(0)->worldLocation;
	normal = Cross(v1, v2).GetNormalized();

	if (vertexNormal)
	{
		if (Dot(normal, GetVertexNormal(0)->worldDirection + GetVertexNormal(1)->worldDirection + GetVertexNormal(2)->worldDirection) < 0)
		{
			//int temp = vertexIdx[1];
			//vertexIdx[1] = vertexIdx[2];
			//vertexIdx[2] = temp;
			normal = -normal;
		}
	}

	distance = -Dot(GetVertex(0)->worldLocation, normal);
}

void Triangle::Reverse()
{
	normal = -normal;
	distance = -Dot(GetVertex(0)->worldLocation, normal);
}

Vertex* Triangle::GetVertex(DeviceWorld* world, int idx)
{
	return world->vertices + vertexIdx[idx];
}

Normal* Triangle::GetNormal(DeviceWorld* world, int idx)
{
	//return world->normals + normalIdx[idx];
	return nullptr;
}

Material* Triangle::GetMaterial(DeviceWorld* world)
{
	return world->materials + materialIdx;
}

Vector3 Triangle::GetNormal(DeviceWorld* world, const Vector3& barycentricCoordinate)
{
	if (vertexNormal)
	{
		return GetVertex(world, 0)->worldDirection * barycentricCoordinate.x + 
			   GetVertex(world, 1)->worldDirection * barycentricCoordinate.y + 
			   GetVertex(world, 2)->worldDirection * barycentricCoordinate.z;
	}
	else
	{
		return normal;
	}
}

Vector3 Triangle::GetAlbedo(DeviceWorld* world, const Vector3& barycentricCoordinate)
{
	if (GetMaterial(world)->textureIdx >= 0)
	{
		Texture* texture = world->textures + GetMaterial(world)->textureIdx;
		return texture->GetColor(world, GetVertex(world, 0)->textureCoordinate.x, GetVertex(world, 0)->textureCoordinate.y) * barycentricCoordinate.x +
			texture->GetColor(world, GetVertex(world, 1)->textureCoordinate.x, GetVertex(world, 1)->textureCoordinate.y) * barycentricCoordinate.y +
			texture->GetColor(world, GetVertex(world, 2)->textureCoordinate.x, GetVertex(world, 2)->textureCoordinate.y) * barycentricCoordinate.z;
	}	
	else
	{
		return (world->materials + materialIdx)->albedo;
	}
}

bool Triangle::IncludeDetect(DeviceWorld* world, Vector3& location, Vector3& coordinate)
{
	//int vIdx1 = vertexIdx[0] * 3;
	//int vIdx2 = vertexIdx[1] * 3;
	//int vIdx3 = vertexIdx[2] * 3;
	//Vector3 vLocation1(vertices[vIdx1], vertices[vIdx1 + 1], vertices[vIdx1 + 2]);
	//Vector3 vLocation2(vertices[vIdx2], vertices[vIdx2 + 1], vertices[vIdx2 + 2]);
	//Vector3 vLocation3(vertices[vIdx3], vertices[vIdx3 + 1], vertices[vsIdx3 + 2]);
	Vector3 vLocation1 = world->vertices[vertexIdx[0]].worldLocation;
	Vector3 vLocation2 = world->vertices[vertexIdx[1]].worldLocation;
	Vector3 vLocation3 = world->vertices[vertexIdx[2]].worldLocation;

	Vector3 ab = vLocation2 - vLocation1;
	Vector3 ac = vLocation3 - vLocation1;
	Vector3 ap = location - vLocation1;

	float abab = Dot(ab, ab);
	float acac = Dot(ac, ac);
	float abac = Dot(ab, ac);
	float apab = Dot(ap, ab);
	float apac = Dot(ap, ac);

	float f = abab * acac - abac * abac;

	coordinate.z = (abab * apac - abac * apab) / f;
	if (coordinate.z < 0 || coordinate.z > 1)
	{
		return false;
	}
	coordinate.y = (acac * apab - abac * apac) / f;
	if (coordinate.y < 0 || coordinate.y > 1)
	{
		return false;
	}
	coordinate.x = (1 - coordinate.y - coordinate.z);
	if (coordinate.x < 0)
	{
		return false;
	}
	return true;
}

bool Triangle::HitDetect(DeviceWorld* world, Ray* ray, RayHitResult* hitResult)
{
	Vector3 n = normal;
	float in = Dot(ray->direction, n);
	float d = this->distance;

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

	if (!IncludeDetect(world, location, coordinate))
	{
		return false;
	}
	hitResult->isHit = true;
	hitResult->material = world->materials + materialIdx;
	hitResult->color = GetAlbedo(world, coordinate);
	hitResult->distance = distance;
	hitResult->location = location;
	hitResult->normal = n;

	return true;
}