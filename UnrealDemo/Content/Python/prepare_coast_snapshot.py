from pathlib import Path
import unreal as u
SOURCE='/Game/Voyage/AtlanticVoyage'
BACKUP='/Game/VoyageRecovery/CoastSnapshot'
asset=u.EditorAssetLibrary.duplicate_asset(SOURCE,BACKUP)
assert asset
assert u.EditorAssetLibrary.save_loaded_asset(asset,False)
u.log('COAST_RECOVERY_COPY_SAVED')
