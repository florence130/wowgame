using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using UnityEditor.SceneManagement;
using DungeonArchitect;
using DungeonArchitect.Builders.Grid;
using DungeonArchitect.Utils;

// Explicit polygon authoring defines the monastery. The real DA grid builder
// validates its painted footprint and emits markers; it does not invent the design.
public static class SanctumSpatialWorkshop {
    public class Input { public string version; public int[][] cells; public SanctumWorkshop.MeshDump[] meshes; }
    public static void Build() {
        var input=Newtonsoft.Json.JsonConvert.DeserializeObject<Input>(File.ReadAllText("Assets/SanctumWorkshop/spatial_mesh_input.json"));
        EditorSceneManager.NewScene(NewSceneSetup.EmptyScene,NewSceneMode.Single);
        var go=new GameObject("DA_AuthoredFootprint");
        var cfg=go.AddComponent<GridDungeonConfig>();cfg.Seed=20261011;cfg.NumCells=0;cfg.GridCellSize=new Vector3(4,2,4);cfg.SpanningTreeLoopProbability=0;
        var model=go.AddComponent<GridDungeonModel>();var builder=go.AddComponent<GridDungeonBuilder>();var tool=go.AddComponent<GridDungeonToolData>();
        var dungeon=go.AddComponent<Dungeon>();dungeon.dungeonThemes=new List<DungeonArchitect.Graphs.Graph>();
        foreach(var c in input.cells)tool.paintedCells.Add(new IntVector(c[0],c[1],c[2]));
        builder.BuildDungeon(cfg,model);builder.EmitMarkers();
        if(builder.Markers.Count==0)throw new Exception("No DA markers");
        var root=new GameObject("SpatialSanctum").transform;
        var mats=new Dictionary<string,Material>();
        string dir="Assets/SanctumWorkshop/SpatialGeometry";Directory.CreateDirectory(dir);
        foreach(var part in input.meshes) {
            var parent=root.Find(part.group);if(!parent){parent=new GameObject(part.group).transform;parent.parent=root;}
            var g=new GameObject(part.name);g.transform.parent=parent;
            var mesh=new Mesh();mesh.name=part.name;
            if(part.positions.Length/3>65000)mesh.indexFormat=UnityEngine.Rendering.IndexFormat.UInt32;
            var vs=new Vector3[part.positions.Length/3];for(int i=0;i<vs.Length;i++)vs[i]=new Vector3(part.positions[i*3],part.positions[i*3+1],part.positions[i*3+2]);
            mesh.vertices=vs;mesh.triangles=part.triangles;mesh.RecalculateNormals();mesh.RecalculateBounds();
            string path=dir+"/"+part.name+".asset";var saved=AssetDatabase.LoadAssetAtPath<Mesh>(path);
            if(saved){EditorUtility.CopySerialized(mesh,saved);UnityEngine.Object.DestroyImmediate(mesh);mesh=saved;EditorUtility.SetDirty(mesh);}else AssetDatabase.CreateAsset(mesh,path);
            g.AddComponent<MeshFilter>().sharedMesh=mesh;
            string key=string.Join("_",part.color);Material mat;
            if(!mats.TryGetValue(key,out mat)) {
                mat=new Material(Shader.Find("Standard"));mat.color=new Color(part.color[0],part.color[1],part.color[2],1);mat.SetFloat("_Glossiness",.1f);
                string mp=dir+"/mat_"+mats.Count+".mat";var old=AssetDatabase.LoadAssetAtPath<Material>(mp);
                if(old){EditorUtility.CopySerialized(mat,old);UnityEngine.Object.DestroyImmediate(mat);mat=old;EditorUtility.SetDirty(mat);}else AssetDatabase.CreateAsset(mat,mp);
                mats[key]=mat;
            }
            g.AddComponent<MeshRenderer>().sharedMaterial=mat;g.AddComponent<MeshCollider>().sharedMesh=mesh;
        }
        var sun=new GameObject("Sun").AddComponent<Light>();sun.type=LightType.Directional;sun.transform.rotation=Quaternion.Euler(48,-32,0);sun.intensity=1.15f;
        RenderSettings.ambientLight=new Color(.45f,.48f,.53f);
        Directory.CreateDirectory("Assets/SanctumWorkshop/Scenes");
        EditorSceneManager.SaveScene(EditorSceneManager.GetActiveScene(),"Assets/SanctumWorkshop/Scenes/WindwhisperSanctumSpatial.unity");AssetDatabase.SaveAssets();
        var dumps=new List<SanctumWorkshop.MeshDump>();
        foreach(var mf in root.GetComponentsInChildren<MeshFilter>()) {
            var mesh=mf.sharedMesh;var ps=new List<float>();var ns=new List<float>();
            foreach(var v in mesh.vertices){var p=mf.transform.TransformPoint(v);ps.AddRange(new[]{p.x,p.y,p.z});}
            foreach(var v in mesh.normals){var n=mf.transform.TransformDirection(v);ns.AddRange(new[]{n.x,n.y,n.z});}
            var c=mf.GetComponent<MeshRenderer>().sharedMaterial.color;
            dumps.Add(new SanctumWorkshop.MeshDump{name=mf.name,group=mf.transform.parent.name,color=new[]{c.r,c.g,c.b,1f},positions=ps.ToArray(),normals=ns.ToArray(),triangles=mesh.triangles});
        }
        string outdir=Path.GetFullPath(Path.Combine(Application.dataPath,"../../export"));Directory.CreateDirectory(outdir);
        File.WriteAllText(Path.Combine(outdir,"unity_spatial_geometry.json"),JsonUtility.ToJson(new SanctumWorkshop.Export{version=input.version,source="Unity 2022.3 saved polygon Mesh assets; Dungeon Architect 1.22.0 painted footprint / EmitMarkers",cells=model.Cells.Count,markers=builder.Markers.Count,meshes=dumps.ToArray()}));
        Debug.Log("SANCTUM SPATIAL BUILD DONE "+model.Cells.Count+" cells / "+builder.Markers.Count+" markers / "+dumps.Count+" saved meshes");
    }
}
