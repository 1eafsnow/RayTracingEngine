#include <Object/Vertex.h>

Vertex::Vertex(Vector3 location) : worldLocation(location)
{

}

void Vertex::SetWorldLocation(Vector3 location)
{
	worldLocation = location;
}

Normal::Normal(Vector3 direction) : worldDirection(direction)
{

}

void Normal::SetWorldDirection(Vector3 direction)
{
	worldDirection = direction;
}