"""Place a small set of rocky shoreline sections using actual terrain traces.
Only the optional coast is modified. Terrain collision state is restored in finally.
"""
from pathlib import Path
import math,json,unreal as u
world=u.get_editor_subsystem(u.UnrealEditorSubsystem).get_editor_world()
assert world.get_path_name().startswith('/Game/Demo/AtlanticCoast.')
sub=u.get_editor_subsystem(u.EditorActorSubsystem)
actors=sub.get_all_level_actors()
land=next(a for a in actors if a.get_actor_label().startswith('Côte'))
comp=land.static_mesh_component;previous=comp.get_collision_enabled()
mesh=u.load_asset('/Game/Demo/Scenery/CoastalCliff01/CoastalCliffRuntime')
# Stable labels make reruns update only these additions.
existing={a.get_actor_label():a for a in actors if a.get_actor_label().startswith('Rivage rocheux ')}
ignore=[a for a in actors if a!=land]
def terrain(x,y):
 hit=u.SystemLibrary.line_trace_single(world,u.Vector(x,y,40000),u.Vector(x,y,-15000),u.TraceTypeQuery.TRACE_TYPE_QUERY1,True,ignore,u.DrawDebugTrace.NONE,True)
 if not hit:raise RuntimeError('Terrain trace missed')
 values=hit.to_tuple()
 if values[9]!=land:raise RuntimeError('Trace hit unexpected actor')
 return values[4].z
records=[]
try:
 comp.set_collision_enabled(u.CollisionEnabled.QUERY_ONLY)
 for idx,degrees in enumerate([205,224,243,261,278,296,316,336]):
  a=math.radians(degrees);dx=57000*math.cos(a);dy=32500*math.sin(a)
  lo,hi=0.40,1.40
  for _ in range(20):
   r=(lo+hi)/2
   if terrain(80000+dx*r,50000+dy*r)>0:lo=r
   else:hi=r
  r=(lo+hi)/2;x=80000+dx*r;y=50000+dy*r
  # Orient long axis along the local shoreline, with the photographed +Y face toward the open sea.
  gradient_x=(terrain(x+50,y)-terrain(x-50,y))/100
  gradient_y=(terrain(x,y+50)-terrain(x,y-50))/100
  yaw=math.degrees(math.atan2(-gradient_x,gradient_y))+180.0
  slope=max(math.hypot(gradient_x,gradient_y),0.01)
  x+=80*gradient_x/slope;y+=80*gradient_y/slope
  label='Rivage rocheux %02d'%(idx+1)
  rock=existing.get(label) or sub.spawn_actor_from_class(u.StaticMeshActor,u.Vector(x,y,-200))
  rock.set_actor_label(label)
  rock.static_mesh_component.set_static_mesh(mesh)
  rock.static_mesh_component.set_collision_enabled(u.CollisionEnabled.NO_COLLISION)
  rock.set_actor_location(u.Vector(x,y,-200),False,False)
  rock.set_actor_rotation(u.Rotator(pitch=0,yaw=yaw,roll=(-1.4 if idx%2 else 1.0)),False)
  scale=[0.72,0.86,0.78,0.93,0.82,0.76,0.89,0.74][idx]
  rock.set_actor_scale3d(u.Vector(scale,scale,scale))
  records.append(dict(label=label,position=[x,y,-200],yaw=yaw,scale=scale,ground_cm=terrain(x,y)))
finally:comp.set_collision_enabled(previous)
u.get_editor_subsystem(u.LevelEditorSubsystem).save_current_level()
(Path(u.Paths.project_dir())/'Docs/coast-outcrops.json').write_text(json.dumps(records,indent=2))
u.log('COAST_OUTCROPS_PLACED '+str(len(records)))
