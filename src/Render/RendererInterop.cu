#include <Render/Renderer.h>
#include <cstdio>

bool Renderer::RegisterOpenGLPixelBuffers(const unsigned int* bufferObjects, int count)
{
    if (bufferObjects == nullptr || count < OpenGLPixelBufferCount)
    {
        return false;
    }

    for (int i = 0; i < OpenGLPixelBufferCount; i++)
    {
        if (bufferObjects[i] == 0)
        {
            return false;
        }
        for (int j = 0; j < i; j++)
        {
            if (bufferObjects[i] == bufferObjects[j])
            {
                fprintf(stderr, "OpenGL pixel buffer %u was supplied more than once.\n", bufferObjects[i]);
                return false;
            }
        }
    }

    UnregisterOpenGLPixelBuffers();
    for (int i = 0; i < OpenGLPixelBufferCount; i++)
    {
        cudaError_t error = cudaGraphicsGLRegisterBuffer(&cudaPixelBufferResources[i], bufferObjects[i], cudaGraphicsRegisterFlagsWriteDiscard);
        if (error != cudaSuccess)
        {
            fprintf(stderr, "cudaGraphicsGLRegisterBuffer[%d] failed with error \"%s\".\n", i, cudaGetErrorString(error));
            UnregisterOpenGLPixelBuffers();
            return false;
        }
        pixelBufferObjects[i] = bufferObjects[i];
    }

    preparedPixelBufferIndex = 0;
    cudaPixelBufferResource = cudaPixelBufferResources[preparedPixelBufferIndex];
    pixelBufferObject = pixelBufferObjects[preparedPixelBufferIndex];
    graphicsInteropEnabled = true;
    printf("CUDA/OpenGL double PBO interop enabled.\n");
    return true;
}

void Renderer::PrepareOpenGLPixelBufferForFrame()
{
    if (!graphicsInteropEnabled)
    {
        preparedPixelBufferIndex = -1;
        cudaPixelBufferResource = nullptr;
        pixelBufferObject = 0;
        return;
    }

    const int writeIndex = frame % OpenGLPixelBufferCount;
    if (cudaPixelBufferResources[writeIndex] == nullptr || pixelBufferObjects[writeIndex] == 0)
    {
        graphicsInteropEnabled = false;
        preparedPixelBufferIndex = -1;
        cudaPixelBufferResource = nullptr;
        pixelBufferObject = 0;
        return;
    }

    preparedPixelBufferIndex = writeIndex;
    cudaPixelBufferResource = cudaPixelBufferResources[writeIndex];
    pixelBufferObject = pixelBufferObjects[writeIndex];
}

void Renderer::UnregisterOpenGLPixelBuffers()
{
    graphicsInteropEnabled = false;
    preparedPixelBufferIndex = -1;
    cudaPixelBufferResource = nullptr;
    pixelBufferObject = 0;

    for (int i = 0; i < OpenGLPixelBufferCount; i++)
    {
        if (cudaPixelBufferResources[i] != nullptr)
        {
            cudaError_t error = cudaGraphicsUnregisterResource(cudaPixelBufferResources[i]);
            if (error != cudaSuccess)
            {
                fprintf(stderr, "cudaGraphicsUnregisterResource[%d] failed with error \"%s\".\n", i, cudaGetErrorString(error));
            }
            cudaPixelBufferResources[i] = nullptr;
        }
        pixelBufferObjects[i] = 0;
    }
}

int Renderer::GetCompletedOpenGLPixelBufferIndex() const
{
    if (!graphicsInteropEnabled || frame <= 0)
    {
        return -1;
    }

    const int completedIndex = (frame - 1) % OpenGLPixelBufferCount;
    if (cudaPixelBufferResources[completedIndex] == nullptr || pixelBufferObjects[completedIndex] == 0)
    {
        return -1;
    }
    return completedIndex;
}

unsigned int Renderer::GetCompletedOpenGLPixelBufferObject() const
{
    const int completedIndex = GetCompletedOpenGLPixelBufferIndex();
    return completedIndex >= 0 ? pixelBufferObjects[completedIndex] : 0;
}
