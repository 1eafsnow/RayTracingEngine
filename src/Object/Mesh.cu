#include <Object/Mesh.h>
#include <World/World.h>

Material* Mesh::GetMaterial()
{
	return GetWorld()->GetMaterial(materialIdx);
}