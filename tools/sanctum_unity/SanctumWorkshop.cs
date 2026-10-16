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

// The plugin builds and emits the actual layout. This is the authored sanctum theme
// and an exporter of the resulting Unity scene, not a substitute dungeon builder.
public static class SanctumWorkshop {
    [Serializable] public class Room { public string id,name,kind,theme,boss,poi; public float[] center,size; }
    [Serializable] public class Connection { public string id,from,to,door_flag,gate_name; public float[][] points; public float width; }
    // JsonUtility does not support nested arrays; use Json.NET shipped with the plugin.
    public class Layout { public string version; public float grid,floor_height; public Room[] rooms; public Connection[] connections; }
    [Serializable] public class MeshDump { public string name,group; public float[] color,positions,normals; public int[] triangles; }
    [Serializable] public class Export { public string version,source; public int cells,markers; public MeshDump[] meshes; }
    static Layout plan;
    static Transform geo;
    static Dictionary<string,Material> materials = new Dictionary<string,Material>();
    static string Dir => Path.GetFullPath(Path.Combine(Application.dataPath, "../../"));

    public static void Build() {
        plan = Newtonsoft.Json.JsonConvert.DeserializeObject<Layout>(File.ReadAllText("Assets/SanctumWorkshop/layout.json"));
        EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
        var dgo = new GameObject("DungeonArchitect_AuthoredSanctum");
        var cfg = dgo.AddComponent<GridDungeonConfig>();
        cfg.Seed = 20261011; cfg.NumCells=0; cfg.GridCellSize=new Vector3(4,2,4);
        cfg.SpanningTreeLoopProbability=0;
        var model=dgo.AddComponent<GridDungeonModel>();
        var builder=dgo.AddComponent<GridDungeonBuilder>();
        var tool=dgo.AddComponent<GridDungeonToolData>();
        var dungeon=dgo.AddComponent<Dungeon>(); dungeon.dungeonThemes=new List<DungeonArchitect.Graphs.Graph>();
        var cells=new HashSet<string>();
        Action<float,float> paint=(x,z)=>{
            int ix=Mathf.FloorToInt(x/4), iz=Mathf.FloorToInt(z/4);
            string key=ix+","+iz;
            if(cells.Add(key)) tool.paintedCells.Add(new IntVector(ix,0,iz));
        };
        foreach(var r in plan.rooms) {
            var volume=new GameObject(r.id+"_"+r.name);
            volume.transform.position=new Vector3(r.center[0],0,r.center[1]);
            // Editable design handles are retained in the Unity source scene.
            var bounds=volume.AddComponent<BoxCollider>(); bounds.size=new Vector3(r.size[0],.2f,r.size[1]); bounds.isTrigger=true;
            for(float x=r.center[0]-r.size[0]/2+2;x<r.center[0]+r.size[0]/2;x+=4)
                for(float z=r.center[1]-r.size[1]/2+2;z<r.center[1]+r.size[1]/2;z+=4) paint(x,z);
        }
        foreach(var c in plan.connections) for(int i=0;i<c.points.Length-1;i++) {
            var a=c.points[i];var b=c.points[i+1];
            float minx=Mathf.Min(a[0],b[0])-c.width/2,maxx=Mathf.Max(a[0],b[0])+c.width/2;
            float minz=Mathf.Min(a[1],b[1])-c.width/2,maxz=Mathf.Max(a[1],b[1])+c.width/2;
            for(float x=minx+2;x<maxx;x+=4) for(float z=minz+2;z<maxz;z+=4) paint(x,z);
        }
        builder.BuildDungeon(cfg,model); builder.EmitMarkers();
        if(builder.Markers.Count==0) throw new Exception("Dungeon Architect emitted no markers");
        geo=new GameObject("SanctumGeometry").transform;
        var markerCounts=builder.Markers.GroupBy(m=>m.SocketType).ToDictionary(g=>g.Key,g=>g.Count());
        foreach(var marker in builder.Markers) {
            var mt=marker.Transform; Vector3 p=mt.MultiplyPoint3x4(Vector3.zero);
            var rotation=mt.rotation;
            var r=FindRoom(p.x,p.z);string theme=r!=null?r.theme:"cloister";
            Color stone=ColorFor(theme), trim=Color.Lerp(stone,new Color(.82f,.78f,.65f),.35f);
            if(marker.SocketType=="Ground") {
                float variation=((Mathf.FloorToInt(p.x)+Mathf.FloorToInt(p.z)*7)%5)*.012f;
                Box("Floor","floor",p+Vector3.down*.17f,new Vector3(4,.34f,4),ColorFor(theme,true)* (1-variation));
            } else if(marker.SocketType=="Fence" || marker.SocketType=="Wall") {
                Box("StoneBoundary","walls",p+Vector3.up*2.65f,new Vector3(4,5.3f,.7f),stone,rotation);
                Box("Foundation","walls",p+Vector3.up*.35f,new Vector3(4,.7f,1.05f),stone*.85f,rotation);
                Box("Cornice","walls",p+Vector3.up*5.32f,new Vector3(4,.22f,.9f),trim,rotation);
                Box("ReliefBand","detail",p+Vector3.up*1.1f,new Vector3(4,.13f,.78f),trim,rotation);
                // Wall buttresses frame corridors and keep the silhouette monastic.
                if(((int)p.x+(int)p.z)%8==0) Box("Buttress","walls",p+Vector3.up*2.8f,new Vector3(.55f,5.6f,1.2f),trim,rotation);
            }
        }
        foreach(var r in plan.rooms) Decorate(r);
        foreach(var c in plan.connections) {
            var a=c.points[0];var b=c.points[1];
            float yaw=Mathf.Abs(b[0]-a[0])>0?90:0;
            Arch(new Vector3(a[0],0,a[1]),yaw,c.width,6.4f,ColorFor("cloister"));
            // A bright exit end and pairs of lamps provide navigation without arrows.
            var e=c.points[c.points.Length-1]; var pre=c.points[c.points.Length-2];
            bool vertical=Mathf.Abs(e[1]-pre[1])>0;
            for(int s=-1;s<=1;s+=2) {
                Vector3 lamp=new Vector3(e[0]+(vertical?s*5:0),1.8f,e[1]+(vertical?0:s*5));
                Box("ExitLantern","detail",lamp,new Vector3(.4f,.8f,.4f),new Color(.95f,.68f,.28f));
            }
        }
        // A terminal silhouette visible above the cloister walls throughout the route.
        var final=plan.rooms.Last();Vector3 fc=new Vector3(final.center[0],0,final.center[1]-19);
        for(int s=-1;s<=1;s+=2) Box("BellTowerPier","walls",fc+new Vector3(s*6,9,0),new Vector3(3,18,3),ColorFor("bell"));
        Box("BellTowerBeam","walls",fc+new Vector3(0,16,0),new Vector3(16,1.1f,4),ColorFor("bell"));
        Box("BellTowerRoof","detail",fc+new Vector3(0,19,0),new Vector3(18,.8f,7),new Color(.22f,.27f,.33f));
        var sun=new GameObject("Sun").AddComponent<Light>();sun.type=LightType.Directional;sun.transform.rotation=Quaternion.Euler(48,-32,0);sun.intensity=1.15f;
        RenderSettings.ambientLight=new Color(.45f,.48f,.53f);
        Directory.CreateDirectory("Assets/SanctumWorkshop/Scenes");
        EditorSceneManager.SaveScene(EditorSceneManager.GetActiveScene(),"Assets/SanctumWorkshop/Scenes/WindwhisperSanctum.unity");
        var dumps=new List<MeshDump>();
        foreach(var mf in geo.GetComponentsInChildren<MeshFilter>()) {
            var mesh=mf.sharedMesh;var v=mesh.vertices;var ns=mesh.normals;
            var pts=new List<float>();var norms=new List<float>();
            for(int i=0;i<v.Length;i++) {
                var q=mf.transform.TransformPoint(v[i]); pts.AddRange(new[]{q.x,q.y,q.z});
                var n=mf.transform.TransformDirection(ns[i]).normalized;norms.AddRange(new[]{n.x,n.y,n.z});
            }
            var color=mf.GetComponent<MeshRenderer>().sharedMaterial.color;
            dumps.Add(new MeshDump{name=mf.name,group=mf.transform.parent.name,color=new[]{color.r,color.g,color.b,1f},positions=pts.ToArray(),normals=norms.ToArray(),triangles=mesh.triangles});
        }
        string outdir=Path.Combine(Dir,"export");Directory.CreateDirectory(outdir);
        File.WriteAllText(Path.Combine(outdir,"unity_geometry.json"),JsonUtility.ToJson(new Export{version=plan.version,source="Unity 2022.3 + Dungeon Architect 1.22.0 GridDungeonBuilder paintedCells / EmitMarkers",cells=model.Cells.Count,markers=builder.Markers.Count,meshes=dumps.ToArray()}));
        File.WriteAllText(Path.Combine(outdir,"builder_report.json"),Newtonsoft.Json.JsonConvert.SerializeObject(new{version=plan.version,cells=model.Cells.Count,markers=builder.Markers.Count,markerCounts,scene="Assets/SanctumWorkshop/Scenes/WindwhisperSanctum.unity"},Newtonsoft.Json.Formatting.Indented));
        if(SystemInfo.graphicsDeviceType!=UnityEngine.Rendering.GraphicsDeviceType.Null) {
            Preview(outdir,"unity_overview",new Vector3(200,270,410),new Vector3(200,0,228),190,true);
            Preview(outdir,"unity_entry",new Vector3(200,9,374),new Vector3(200,4,310),0,false);
            Preview(outdir,"unity_garden",new Vector3(87,13,237),new Vector3(80,3,216),0,false);
            Preview(outdir,"unity_nave",new Vector3(152,13,96),new Vector3(120,4,86),0,false);
        }
        AssetDatabase.SaveAssets();Debug.Log("SANCTUM UNITY BUILD DONE "+model.Cells.Count+" cells / "+builder.Markers.Count+" markers / "+dumps.Count+" meshes");
    }
    static Room FindRoom(float x,float z) => plan.rooms.FirstOrDefault(r=>Mathf.Abs(x-r.center[0])<=r.size[0]/2 && Mathf.Abs(z-r.center[1])<=r.size[1]/2);
    static Color ColorFor(string theme,bool floor=false) {
        if(floor) { if(theme=="garden")return new Color(.37f,.43f,.29f); if(theme=="depot")return new Color(.48f,.42f,.34f);return new Color(.49f,.50f,.48f); }
        if(theme=="garden")return new Color(.47f,.52f,.37f);if(theme=="nave"||theme=="bell")return new Color(.48f,.51f,.56f);return new Color(.61f,.59f,.50f);
    }
    static Transform Group(string name) {var t=geo.Find(name);if(!t){t=new GameObject(name).transform;t.parent=geo;}return t;}
    static Material Mat(Color color) {string k=ColorUtility.ToHtmlStringRGB(color);if(!materials.ContainsKey(k)){var m=new Material(Shader.Find("Standard"));m.color=color;m.SetFloat("_Glossiness",.12f);materials[k]=m;}return materials[k];}
    static GameObject Box(string name,string group,Vector3 p,Vector3 size,Color color,Quaternion? rot=null) {
        var g=GameObject.CreatePrimitive(PrimitiveType.Cube);g.name=name;g.transform.parent=Group(group);g.transform.position=p;g.transform.localScale=size;g.transform.rotation=rot??Quaternion.identity;g.GetComponent<MeshRenderer>().sharedMaterial=Mat(color);return g;
    }
    static void Arch(Vector3 p,float yaw,float w,float h,Color color) {
        Quaternion q=Quaternion.Euler(0,yaw,0);
        float spring=h-1.8f;
        for(int s=-1;s<=1;s+=2) {
            Box("ArchPier","walls",p+q*new Vector3(s*(w/2+.45f),spring/2,0),new Vector3(.9f,spring,1.3f),color,q);
            Box("ArchCapital","detail",p+q*new Vector3(s*(w/2+.45f),spring-.15f,0),new Vector3(1.1f,.3f,1.55f),Color.Lerp(color,Color.white,.08f),q);
        }
        // Real extruded voussoirs touch the piers and follow an elliptical arch.
        // The lower edge keeps a 4.6m clear height; mortar joints are only 2cm.
        for(int i=0;i<11;i++) {
            float a=i*Mathf.PI/11+.002f,b=(i+1)*Mathf.PI/11-.002f;
            Vector3[] ring={new Vector3(Mathf.Cos(a)*w/2,spring+Mathf.Sin(a)*1.8f,0),
                new Vector3(Mathf.Cos(b)*w/2,spring+Mathf.Sin(b)*1.8f,0),
                new Vector3(Mathf.Cos(b)*(w/2+.9f),spring+Mathf.Sin(b)*2.5f,0),
                new Vector3(Mathf.Cos(a)*(w/2+.9f),spring+Mathf.Sin(a)*2.5f,0)};
            var vertices=new List<Vector3>();var triangles=new List<int>();
            Action<Vector3,Vector3,Vector3,Vector3> face=(v0,v1,v2,v3)=>{
                int n=vertices.Count;vertices.AddRange(new[]{v0,v1,v2,v3});triangles.AddRange(new[]{n,n+1,n+2,n,n+2,n+3});};
            var front=ring.Select(v=>v+Vector3.back*.65f).ToArray();var back=ring.Select(v=>v+Vector3.forward*.65f).ToArray();
            face(front[0],front[1],front[2],front[3]);face(back[3],back[2],back[1],back[0]);
            for(int j=0;j<4;j++) {int k=(j+1)%4;face(front[k],front[j],back[j],back[k]);}
            var mesh=new Mesh();mesh.name="CutArchStone";mesh.SetVertices(vertices);mesh.SetTriangles(triangles,0);mesh.RecalculateNormals();mesh.RecalculateBounds();
            Directory.CreateDirectory("Assets/SanctumWorkshop/Geometry");
            string assetPath="Assets/SanctumWorkshop/Geometry/ArchStone_"+i+".asset";
            var saved=AssetDatabase.LoadAssetAtPath<Mesh>(assetPath);
            if(saved) {EditorUtility.CopySerialized(mesh,saved);UnityEngine.Object.DestroyImmediate(mesh);mesh=saved;EditorUtility.SetDirty(mesh);}
            else AssetDatabase.CreateAsset(mesh,assetPath);
            var go=new GameObject("ArchVoussoir");go.transform.parent=Group("walls");go.transform.position=p;go.transform.rotation=q;
            go.AddComponent<MeshFilter>().sharedMesh=mesh;go.AddComponent<MeshRenderer>().sharedMaterial=Mat(Color.Lerp(color,Color.white,i==5?.16f:.05f));
            go.AddComponent<MeshCollider>().sharedMesh=mesh;
        }
    }
    static void Decorate(Room r) {
        float x=r.center[0],z=r.center[1],w=r.size[0],d=r.size[1];Color stone=ColorFor(r.theme);
        if(r.theme=="garden") {
            foreach(int s in new[]{-1,1}) for(int i=0;i<3;i++) {
                var bed=new Vector3(x+s*(w/2-5),.35f,z-d/2+7+i*(d-14)/2);
                if(LaneClear(r,bed,2.5f)) Box("GardenBed","props",bed,new Vector3(4,.7f,5),new Color(.32f,.39f,.23f));
                Box("IvyPatch","detail",new Vector3(x+s*(w/2-.45f),2.2f,z-d/2+5+i*(d-10)/2),new Vector3(.3f,3.5f,3.3f),new Color(.28f,.40f,.24f));
            }
        } else if(r.theme=="depot") {
            for(int s=-1;s<=1;s+=2) for(int i=0;i<3;i++) {
                var stack=new Vector3(x+s*(w/2-4),.9f,z-d/2+6+i*4);
                if(LaneClear(r,stack,1.8f)) Box("SupplyStack","props",stack,new Vector3(2.5f,1.8f,2.5f),new Color(.43f,.32f,.23f));
                Box("GrayBandana","detail",new Vector3(x+s*(w/2-.5f),3,z+5),new Vector3(.2f,2.5f,1.4f),new Color(.26f,.28f,.31f));
            }
        } else if(r.theme=="nave") {
            for(int s=-1;s<=1;s+=2) for(int i=0;i<3;i++) {
                var bench=new Vector3(x+s*(w/2-6),.65f,z-d/2+7+i*6);
                if(LaneClear(r,bench,2.2f)) Box("ChoirBench","props",bench,new Vector3(4,1.3f,1.2f),new Color(.32f,.27f,.24f));
                Box("WindowRecess","detail",new Vector3(x+s*(w/2-.4f),3,z-d/2+6+i*7),new Vector3(.2f,2.2f,1.5f),new Color(.22f,.28f,.37f));
            }
        } else {
            for(int s=-1;s<=1;s+=2) for(int i=0;i<3;i++) {
                var pier=new Vector3(x+s*(w/2-.7f),3,z-d/2+5+i*(d-10)/2);
                if(LaneClear(r,pier,.8f)) Box("CloisterPilaster","walls",pier,new Vector3(1,6,1),stone);
            }
        }
        if(r.kind=="boss"||r.kind=="final") {
            // A clear centre for telegraphs; ornament stays at the room edges.
            Box("ArenaMedallion","floor",new Vector3(x,.035f,z),new Vector3(18,.07f,18),Color.Lerp(ColorFor(r.theme,true),new Color(.72f,.66f,.51f),.16f));
        }
        if(r.kind=="rest") Box("RestAltar","props",new Vector3(x-w/2+3,1,z+3),new Vector3(3,2,2),stone);
    }
    static bool LaneClear(Room r,Vector3 p,float extent) {
        var centre=new Vector2(r.center[0],r.center[1]);var point=new Vector2(p.x,p.z);
        foreach(var c in plan.connections) {
            float[] endpoint=c.from==r.id?c.points[0]:(c.to==r.id?c.points.Last():null);
            if(endpoint==null)continue;
            var e=new Vector2(endpoint[0],endpoint[1]);var d=e-centre;
            float t=Mathf.Clamp01(Vector2.Dot(point-centre,d)/Mathf.Max(.001f,d.sqrMagnitude));
            if(Vector2.Distance(point,centre+d*t)<3.2f+extent)return false;
        }
        return true;
    }
    static void Preview(string dir,string name,Vector3 eye,Vector3 target,float ortho,bool top) {
        var go=new GameObject("Preview");var c=go.AddComponent<Camera>();c.transform.position=eye;c.transform.LookAt(target);c.backgroundColor=new Color(.15f,.19f,.22f);c.clearFlags=CameraClearFlags.SolidColor;c.nearClipPlane=.2f;c.farClipPlane=1000;
        c.orthographic=top;c.orthographicSize=ortho;var rt=new RenderTexture(1600,1000,24);c.targetTexture=rt;c.Render();RenderTexture.active=rt;
        var tex=new Texture2D(1600,1000,TextureFormat.RGB24,false);tex.ReadPixels(new Rect(0,0,1600,1000),0,0);tex.Apply();File.WriteAllBytes(Path.Combine(dir,name+".png"),tex.EncodeToPNG());RenderTexture.active=null;c.targetTexture=null;UnityEngine.Object.DestroyImmediate(rt);UnityEngine.Object.DestroyImmediate(tex);UnityEngine.Object.DestroyImmediate(go);
    }
}
