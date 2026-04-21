#include <Core.h>

int windowWidth = 1280;
int windowHeight = 800;

int getThreadNum()
{
    cudaDeviceProp prop;
    int count;

    cudaGetDeviceCount(&count);
    printf("gpu num %d\n", count);
    cudaGetDeviceProperties(&prop, 0);
    printf("max thread num: %d\n", prop.maxThreadsPerBlock);
    printf("max grid dimensions: (%d, %d, %d)\n", prop.maxGridSize[0], prop.maxGridSize[1], prop.maxGridSize[2]);
	printf("const memory: %zu\n", prop.totalConstMem);
    printf("global memory: %zu\n", prop.totalGlobalMem);
    printf("shared mem per block: %zu\n", prop.sharedMemPerBlock);
    
    return prop.maxThreadsPerBlock;
}

int main(int, char**)
{       
    getThreadNum();

    int sphereFront = GetWorld()->CreateSphere();
    GetWorld()->GetSphere(sphereFront)->SetWorldLocation(Vector3(0.0, 0.0, 1000.0));
    GetWorld()->GetSphere(sphereFront)->SetRadius(995.0);
    GetWorld()->GetSphere(sphereFront)->GetMaterial()->isEmit = false;
    GetWorld()->GetSphere(sphereFront)->GetMaterial()->albedo = Vector3(0.8, 0.8, 0.8) / 10;
    GetWorld()->GetSphere(sphereFront)->GetMaterial()->transparency = 0.0;
    GetWorld()->GetSphere(sphereFront)->GetMaterial()->roughness = 0.9;
    GetWorld()->GetSphere(sphereFront)->GetMaterial()->refractionIndex = 2.0;

    int sphereBack = GetWorld()->CreateSphere();
    GetWorld()->GetSphere(sphereBack)->SetWorldLocation(Vector3(0.0, 0.0, -1000.0));
    GetWorld()->GetSphere(sphereBack)->SetRadius(995.0);
    GetWorld()->GetSphere(sphereBack)->GetMaterial()->isEmit = false;
    GetWorld()->GetSphere(sphereBack)->GetMaterial()->albedo = Vector3(0.8, 0.8, 0.8) / 10;
    GetWorld()->GetSphere(sphereBack)->GetMaterial()->transparency = 0.0;
    GetWorld()->GetSphere(sphereBack)->GetMaterial()->roughness = 0.9;
    GetWorld()->GetSphere(sphereBack)->GetMaterial()->refractionIndex = 2.0;

    int sphereLeft = GetWorld()->CreateSphere();
    GetWorld()->GetSphere(sphereLeft)->SetWorldLocation(Vector3(-1000.0, 0.0, 0.0));
    GetWorld()->GetSphere(sphereLeft)->SetRadius(995.0);
    GetWorld()->GetSphere(sphereLeft)->GetMaterial()->isEmit = false;
    GetWorld()->GetSphere(sphereLeft)->GetMaterial()->albedo = Vector3(255.0 / 255.0, 20.0 / 255.0, 147.0 / 255.0) / 10;
    GetWorld()->GetSphere(sphereLeft)->GetMaterial()->transparency = 0.0;
    GetWorld()->GetSphere(sphereLeft)->GetMaterial()->roughness = 0.9;
    GetWorld()->GetSphere(sphereLeft)->GetMaterial()->refractionIndex = 2.0;

    int sphereRight = GetWorld()->CreateSphere();
    GetWorld()->GetSphere(sphereRight)->SetWorldLocation(Vector3(1000.0, 0.0, 0.0));
    GetWorld()->GetSphere(sphereRight)->SetRadius(995.0);
    GetWorld()->GetSphere(sphereRight)->GetMaterial()->isEmit = false;
    GetWorld()->GetSphere(sphereRight)->GetMaterial()->albedo = Vector3(0.0, 191.0 / 255.0, 255.0 / 255.0) / 10;
    GetWorld()->GetSphere(sphereRight)->GetMaterial()->transparency = 0.0;
    GetWorld()->GetSphere(sphereRight)->GetMaterial()->roughness = 0.9;
    GetWorld()->GetSphere(sphereRight)->GetMaterial()->refractionIndex = 2.0;

    int sphereTop = GetWorld()->CreateSphere();
    GetWorld()->GetSphere(sphereTop)->SetWorldLocation(Vector3(0.0, 1000.0, 0.0));
    GetWorld()->GetSphere(sphereTop)->SetRadius(995);
    GetWorld()->GetSphere(sphereTop)->GetMaterial()->isEmit = false;
    GetWorld()->GetSphere(sphereTop)->GetMaterial()->albedo = Vector3(0.8, 0.8, 0.8) / 10;
    GetWorld()->GetSphere(sphereTop)->GetMaterial()->transparency = 0.0;
    GetWorld()->GetSphere(sphereTop)->GetMaterial()->roughness = 0.9;
    GetWorld()->GetSphere(sphereTop)->GetMaterial()->refractionIndex = 2.0;

    int sphereBottom = GetWorld()->CreateSphere();
    GetWorld()->GetSphere(sphereBottom)->SetWorldLocation(Vector3(0.0, -1000.0, 0.0));
    GetWorld()->GetSphere(sphereBottom)->SetRadius(995);
    GetWorld()->GetSphere(sphereBottom)->GetMaterial()->isEmit = false;
    GetWorld()->GetSphere(sphereBottom)->GetMaterial()->albedo = Vector3(0.8, 0.8, 0.8) / 10;
    GetWorld()->GetSphere(sphereBottom)->GetMaterial()->transparency = 0.0;
    GetWorld()->GetSphere(sphereBottom)->GetMaterial()->roughness = 0.9;
    GetWorld()->GetSphere(sphereBottom)->GetMaterial()->refractionIndex = 2.0;
    
    int light1 = GetWorld()->CreateSphere();
    GetWorld()->GetSphere(light1)->SetWorldLocation(Vector3(-2.0, 4.0, 0.0));
    GetWorld()->GetSphere(light1)->SetRadius(0.5);
    GetWorld()->GetSphere(light1)->GetMaterial()->isEmit = true;
    GetWorld()->GetSphere(light1)->GetMaterial()->emit = Vector3(1.0, 1.0, 1.0);
    GetWorld()->GetSphere(light1)->GetMaterial()->intensity = 1000;
    /*
    int light2 = GetWorld()->CreateSphere();
    GetWorld()->GetSphere(light2)->GetVertex()->SetWorldLocation(Vector3(-1.0, 4.0, 0.0));
    GetWorld()->GetSphere(light2)->SetRadius(0.5);
    GetWorld()->GetSphere(light2)->GetMaterial()->isEmit = true;
    GetWorld()->GetSphere(light2)->GetMaterial()->emit = Vector3(1.0, 1.0, 1.0);
    GetWorld()->GetSphere(light2)->GetMaterial()->intensity = 1000;
    
    int light3 = GetWorld()->CreateSphere();
    GetWorld()->GetSphere(light3)->GetVertex()->SetWorldLocation(Vector3(0.0, 4.0, 0.0));
    GetWorld()->GetSphere(light3)->SetRadius(0.5);
    GetWorld()->GetSphere(light3)->GetMaterial()->isEmit = true;
    GetWorld()->GetSphere(light3)->GetMaterial()->emit = Vector3(1.0, 1.0, 1.0);
    GetWorld()->GetSphere(light3)->GetMaterial()->intensity = 10000;

    int light4 = GetWorld()->CreateSphere();
    GetWorld()->GetSphere(light4)->GetVertex()->SetWorldLocation(Vector3(1.0, 4.0, 0.0));
    GetWorld()->GetSphere(light4)->SetRadius(0.5);
    GetWorld()->GetSphere(light4)->GetMaterial()->isEmit = true;
    GetWorld()->GetSphere(light4)->GetMaterial()->emit = Vector3(1.0, 1.0, 1.0);
    GetWorld()->GetSphere(light4)->GetMaterial()->intensity = 1000;
    */
    int light5 = GetWorld()->CreateSphere();
    GetWorld()->GetSphere(light5)->SetWorldLocation(Vector3(2.0, 4.0, 0.0));
    GetWorld()->GetSphere(light5)->SetRadius(0.5);
    GetWorld()->GetSphere(light5)->GetMaterial()->isEmit = true;
    GetWorld()->GetSphere(light5)->GetMaterial()->emit = Vector3(1.0, 1.0, 1.0);
    GetWorld()->GetSphere(light5)->GetMaterial()->intensity = 1000;
    
    int sphere1 = GetWorld()->CreateSphere();
    GetWorld()->GetSphere(sphere1)->SetWorldLocation(Vector3(0.0, -4.0, 0.0));
    GetWorld()->GetSphere(sphere1)->SetRadius(1);
    GetWorld()->GetSphere(sphere1)->GetMaterial()->isEmit = false;
    GetWorld()->GetSphere(sphere1)->GetMaterial()->albedo = Vector3(20.0 / 255.0, 235.0 / 255.0, 185.0 / 255.0) / 10;
    GetWorld()->GetSphere(sphere1)->GetMaterial()->transparency = 0.0;
    GetWorld()->GetSphere(sphere1)->GetMaterial()->roughness = 0.1;
    GetWorld()->GetSphere(sphere1)->GetMaterial()->refractionIndex = 1.5;
    
    
    int sphere2 = GetWorld()->CreateSphere();
    GetWorld()->GetSphere(sphere2)->SetWorldLocation(Vector3(2.0, -4.5, -1.0));
    GetWorld()->GetSphere(sphere2)->SetRadius(0.5);
    GetWorld()->GetSphere(sphere2)->GetMaterial()->isEmit = false;
    GetWorld()->GetSphere(sphere2)->GetMaterial()->albedo = Vector3(224.0 / 255.0, 102.0 / 255.0, 255.0 / 255.0) / 10;
    GetWorld()->GetSphere(sphere2)->GetMaterial()->transparency = 0.0;
    GetWorld()->GetSphere(sphere2)->GetMaterial()->roughness = 0.9;
    GetWorld()->GetSphere(sphere2)->GetMaterial()->refractionIndex = 2.0;
    
    /*
	Triangle* tri = CreateTriangle();
    tri->SetVertexWorldLocation(0, Vector3(0, -3.5, 1));
    tri->SetVertexWorldLocation(1, Vector3(1, -4, 0));
    tri->SetVertexWorldLocation(2, Vector3(-1, -4, 0));
    tri->SetVertexWorldNormal(0, Vector3(0, 1, 0));
    tri->SetVertexWorldNormal(1, Vector3(-1, 0, -1));
    tri->SetVertexWorldNormal(2, Vector3(1, 0, -1));
    tri->vertexNormal = false;
    tri->Init();
    tri->GetMaterial()->backVisible = true;
	tri->GetMaterial()->albedo = Vector3(0.8, 0.8, 0.8);
    tri->GetMaterial()->transparency = 0.0;
    tri->GetMaterial()->roughness = 0.9;
    tri->GetMaterial()->refractionIndex = 2.0;    
    */
    /*
	int v0 = GetWorld()->CreateVertex(Vector3(-1, -1, 3)); 
    int v1 = GetWorld()->CreateVertex(Vector3(1, -1, 3));
    int v2 = GetWorld()->CreateVertex(Vector3(1, -3, 2));
    int v3 = GetWorld()->CreateVertex(Vector3(-1, -3, 2));
    int quad = GetWorld()->CreateQuadrilateral({v0, v1, v2, v3});
    GetWorld()->GetQuadrilateral(quad)->vertexNormal = false;
    GetWorld()->GetQuadrilateral(quad)->Init();
    GetWorld()->GetQuadrilateral(quad)->GetMaterial()->backVisible = true;
    GetWorld()->GetQuadrilateral(quad)->GetMaterial()->albedo = Vector3(0.8, 0.0, 0.0);
    GetWorld()->GetQuadrilateral(quad)->GetMaterial()->transparency = 0.0;
    GetWorld()->GetQuadrilateral(quad)->GetMaterial()->roughness = 0.9;
    GetWorld()->GetQuadrilateral(quad)->GetMaterial()->refractionIndex = 2.0;
    */
    /*
	int box = GetWorld()->CreateBox();
    GetWorld()->GetBox(box)->GetMaterial()->albedo = Vector3(0.8, 0.1, 0.5);
    GetWorld()->GetBox(box)->GetMaterial()->transparency = 0.0;
    GetWorld()->GetBox(box)->GetMaterial()->roughness = 0.9;
    GetWorld()->GetBox(box)->GetMaterial()->refractionIndex = 2.0;
    */
    //Model model("C:\\Model\\dog\\Dog.fbx");
    
    float fovX = 60.0;
    float fovY = (atan((float)windowHeight / windowWidth * tan((fovX / 180.0 * PI) / 2))) / PI * 180.0 * 2;
    GetCamera()->focus = 0.01;
    GetCamera()->fovX = fovX;
    GetCamera()->fovY = fovY;
    GetCamera()->worldLocation = Vector3(0.0, -3, -8.0);
    GetCamera()->worldRotation = Rotator(0.0, 0.0, 0.0);
    //camera.SetWorldLocation(Vector3(0.0, 2.0, -10.0));
    //camera.SetWorldRotation(Vector3(0.0, 0.0, 0.0));

    Renderer renderer;
    renderer.width = windowWidth;
	renderer.height = windowHeight;
    renderer.devThreadNum = 32;
    renderer.sampleProb = 0.8;
    renderer.sampleDepth = 8;
    renderer.filterKernelSize = 1;
    renderer.Init();

    GUI gui;
    gui.SetRenderer(&renderer);
	gui.Open();

    while (1)
    {
        renderer.Tick(1);
		gui.Tick(1);
    }

    return 0;
}