"""Switch the Bismarck of /Game/Bismarck/AtlanticBismarck between her two liveries without re-importing:
24mai (Operation Rheinübung, Denmark Strait: stripes and deck markings painted over; war ensign at the
gaff) or 21mai (entering the Korsfjord: black and white stripes, darker ends, red air-recognition panels
with a white disc and a swastika on the forecastle and quarterdeck). The ensign flies in both.
Tools/port-bismarck.sh livery_bismarck.py 21mai   (or 24mai). Saves the mesh only, then quits the editor.
"""
import sys
import time
import unreal as u

LIVERY = next((a for a in sys.argv[1:] if a in ('21mai', '24mai')), None)
start = time.monotonic()
handle = None


def log(text):
    u.log('BISMARCK_LIVERY: ' + text)


def switch():
    if LIVERY is None:
        raise RuntimeError('Give the livery: 21mai or 24mai')
    mesh = u.load_asset('/Game/Bismarck/Meshes/Bismarck')
    for slot, entry in enumerate(mesh.static_materials):
        name = str(entry.material_slot_name)
        if name in ('Bismarck_hull', 'Bismarck_deck'):
            path = '/Game/Bismarck/Materials/M_%s%s' % (name, '_21mai' if LIVERY == '21mai' else '')
            material = u.load_asset(path)
            if material is None:
                raise RuntimeError('Missing ' + path + ' (run port_bismarck.py first)')
            mesh.set_material(slot, material)
            log('%s -> %s' % (name, material.get_name()))
    u.EditorAssetLibrary.save_loaded_asset(mesh, False)
    log('COMPLETE ' + LIVERY)


def tick(delta):
    if time.monotonic() - start < 15:
        return
    u.unregister_slate_post_tick_callback(handle)
    try:
        switch()
    except Exception as error:
        log('FAILED ' + str(error))
    u.SystemLibrary.quit_editor()


handle = u.register_slate_post_tick_callback(tick)
log('STARTED')
