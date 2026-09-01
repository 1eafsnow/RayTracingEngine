#include <Render/Renderer.h>
#include <cstdio>

bool Renderer::RegisterOpenGLPixelBuffers(const unsigned int* bufferObjects, int count)
{
    UnregisterOpenGLPixelBuffers();
    if (bufferObjects == nullptr || count < OpenGLPixelBufferCount)
    {
        return false;
    }

    for (int i = 0; i < OpenGLPixelBufferCount; i++)
    {
        if (bufferObjects[i] == 0)
        {
            UnregisterOpenGLPixelBuffers();
            return false;
        }

        cudaError_t error = cudaGraphicsGLRegisterBuffer(&cudaPixelBufferResources[i], bufferObjects[i], cudaGraphicsRegisterFlagsWriteDiscard);
        if (error != cudaSuccess)
        {
            printf("cudaGraphicsGLRegisterBuffer[%d] failed with error \"%s\".\n", i, cudaGetErrorString(error));
            UnregisterOpenGLPixelBuffers();
            return false;
        }

        pixelBufferObjects[i] = bufferObjects[i];
    }

    preparedPixelBufferIndex = 0;
    cudaPixelBufferResource = cudaPixelBufferResources[0];
    pixelBufferObject = pixelBufferObjects[0];
    graphicsInteropEnabled = true;
    printf("CUDA/OpenGL double PBO interop enabled.\n");
    return true;
}

void Renderer::PrepareOpenGLPixelBufferForFrame()
{
    if (!graphicsInteropEnabled)
    {
        return;
    }

    const int writeIndex = frame & 1;
    if (cudaPixelBufferResources[writeIndex] == nullptr || pixelBufferObjects[writeIndex] == 0)
    {
        graphicsInteropEnabled = false;
        cudaPixelBufferResource = nullptr;
        pixelBufferObject = 0;
        preparedPixelBufferIndex = -1;
        return;
    }

    preparedPixelBufferIndex = writeIndex;
    cudaPixelBufferResource = cudaPixelBufferResources[writeIndex];
    pixelBufferObject = pixelBufferObjects[writeIndex];
}

void Renderer::UnregisterOpenGLPixelBuffers()
{
    graphicsInteropEnabled = false;
    cudaPixelBufferResource = nullptr;
    pixelBufferObject = 0;
    preparedPixelBufferIndex = -1;

    for (int i = 0; i < OpenGLPixelBufferCount; i++)
    {
        if (cudaPixelBufferResources[i] != nullptr)
        {
            cudaError_t error = cudaGraphicsUnregisterResource(cudaPixelBufferResources[i]);
            if (error != cudaSuccess)
            {
                printf("cudaGraphicsUnregisterResource[%d] failed with error \"%s\".\n", i, cudaGetErrorString(error));
            }
            cudaPixelBufferResources[i] = nullptr;
        }
        pixelBufferObjects[i] = 0;
    }
}

unsigned int Renderer::GetCompletedOpenGLPixelBufferObject() const
{
    if (!graphicsInteropEnabled || frame <= 0)
    {
        return 0;
    }

    const int completedIndex = (frame - 1) & 1;
    return pixelBufferObjects[completedIndex];
}