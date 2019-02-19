#pragma once
#include "CommonInclude.h"
#include "wiGraphicsDevice.h"
#include "wiHashString.h"

#include <mutex>
#include <unordered_map>

class wiResourceManager
{
private:
	std::mutex lock;
public:
	enum Data_Type{
		DYNAMIC,
		IMAGE_1D,
		IMAGE_2D,
		IMAGE_3D,
		SOUND,MUSIC,
		VERTEXSHADER,
		PIXELSHADER,
		GEOMETRYSHADER,
		HULLSHADER,
		DOMAINSHADER,
		COMPUTESHADER,
	};

    inline bool isShader(Data_Type t) {
        return (t == VERTEXSHADER) || (t == PIXELSHADER) || (t == GEOMETRYSHADER) || (t == HULLSHADER) || (t == DOMAINSHADER) || (t == COMPUTESHADER);
    }
    
	struct Resource
	{
		void* data;
		Data_Type type;
		long refCount;

		Resource(void* newData, Data_Type newType) :data(newData), type(newType)
		{
			refCount = 1;
		};
	};
	std::unordered_map<wiHashString, Resource*> resources;


public:
	~wiResourceManager() { Clear(); }
	static wiResourceManager& GetGlobal();
	static wiResourceManager& GetShaderManager();

	const Resource* get(const wiHashString& name, bool IncRefCount = false);
	//specify datatype for shaders
	void* add(const wiHashString& name, Data_Type newType = Data_Type::DYNAMIC);
	bool del(const wiHashString& name, bool forceDelete = false);
	bool Register(const wiHashString& name, void* resource, Data_Type newType);
	bool Clear();
};

