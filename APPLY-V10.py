from pathlib import Path
import shutil,re
root=Path('.')
for name in ['index.html','play.html','player.js','multiplayer-host.js']:
 p=root/name
 if not p.exists(): raise SystemExit(f'Missing {name}. Run this inside the current game folder.')
 shutil.copy2(p,root/(name+'.v9.bak'))
# hard-hide projector shop and cache bust
p=root/'index.html'; s=p.read_text(encoding='utf-8')
s=s.replace('config.js?v=9','config.js?v=10').replace('multiplayer-host.js?v=9','multiplayer-host.js?v=10')
if '</style>' in s:s=s.replace('</style>','#shopBtn,#shopScreen,#hearts,#xpChip,#teamScores,#tools,.tools{display:none!important;visibility:hidden!important;pointer-events:none!important}</style>',1)
p.write_text(s,encoding='utf-8')
# host patch
p=root/'multiplayer-host.js'; s=p.read_text(encoding='utf-8')
s=s.replace("if(mpResolving||mpRoom.status!=='question'||G.locked)return;","if(mpResolving||mpRoom.status!=='question')return;")
s=s.replace("let b=[...document.querySelectorAll('.answer')].find(x=>x.dataset.val===winner);if(b)answer(winner,b);","let b=[...document.querySelectorAll('.answer')].find(x=>x.dataset.val===winner);if(b){G.locked=false;G.paused=false;answer(winner,b)}")
s += r'''
// V10: remove stale players and suppress the original single-player shop.
setInterval(async()=>{if(mpRoom){try{await mp.rpc('remove_stale_players',{p_room_id:mpRoom.id,p_seconds:20});refresh()}catch(e){console.warn(e)}}},10000);
const v10Shop=document.getElementById('shopScreen');
if(v10Shop){const hide=()=>{const open=!v10Shop.classList.contains('hidden');v10Shop.classList.add('hidden');v10Shop.style.setProperty('display','none','important');if(open&&!G.over){G.paused=false;const c=document.getElementById('shopClose');if(c)setTimeout(()=>c.click(),0)}};new MutationObserver(hide).observe(v10Shop,{attributes:true});hide()}
const v10Tools=document.getElementById('tools');if(v10Tools)new MutationObserver(()=>{v10Tools.innerHTML='';v10Tools.style.setProperty('display','none','important')}).observe(v10Tools,{childList:true});
'''
p.write_text(s,encoding='utf-8')
# replace item handler and add shop timing + purchase feedback
p=root/'player.js'; s=p.read_text(encoding='utf-8')
start=s.find("document.querySelectorAll('[data-item]').forEach")
end=s.find('// Deliberately no automatic join',start)
if start<0: raise SystemExit('Could not find V9 item handler')
handler=r'''document.querySelectorAll('[data-item]').forEach(button=>button.onclick=async()=>{
 const key=button.dataset.item;if(!player||!room)return toast('Noch nicht verbunden.',false);
 if(room.status!=='question')return toast('Gegenstände funktionieren während einer Frage.',false);
 if((player[key]||0)<=0)return toast('Nicht im Inventar.',false);
 const patch={[key]:player[key]-1};
 if(key==='torch'){
  const choices=[...document.querySelectorAll('#answers button:not(:disabled)')];
  const target=choices.find(x=>x.textContent.trim()===String(room.safe_false||'').trim());
  if(!target)return toast('Keine falsche Antwort gefunden.',false);
  target.disabled=true;target.style.opacity='.2';target.style.textDecoration='line-through';toast('🔥 Falsche Antwort entfernt.',true);
 }else if(key==='book'){$('#hint').textContent='💡 Prüfe gleiche Basis oder gleichen Exponenten.';toast('📖 Hinweis geöffnet.',true)}
 else if(key==='shield'){patch.shield_active=true;toast('🛡 Schild aktiviert.',true)}
 else if(key==='potion'){if(player.hp>=player.max_hp)return toast('Herzen bereits voll.',false);patch.hp=player.hp+1;toast('🧪 Ein Herz geheilt.',true)}
 const {data,error}=await sb.from('players').update(patch).eq('id',user.id).select().single();if(error)return toast(error.message,false);player=data;renderPlayer();
});
function toast(text,ok){let n=document.getElementById('v10toast');if(!n){n=document.createElement('div');n.id='v10toast';document.body.appendChild(n)}n.textContent=text;n.style.cssText=`position:fixed;z-index:999;left:50%;top:18px;transform:translateX(-50%);padding:12px 18px;border-radius:12px;color:white;font-weight:900;background:${ok?'#14563a':'#641a30'};border:3px solid ${ok?'#68e09b':'#ff5470'}`;clearTimeout(n.t);n.t=setTimeout(()=>n.remove(),1800)}
'''
s=s[:start]+handler+s[end:]
# make shop card hidden during question and open at result
s=s.replace("function renderRoom(r){", "function renderRoom(r){const shopCard=$('#shop').parentElement;shopCard.classList.toggle('hidden',r.status==='question');if(r.status==='result'){$('#shop').classList.remove('hidden');$('#shopToggle').textContent='SCHLIESSEN'}")
# purchase confirmation
s=s.replace("player=data;renderPlayer();showPurchase", "player=data;renderPlayer();toast('✓ '+i[1]+' '+i[2]+' gekauft!',true);showPurchase")
p.write_text(s,encoding='utf-8')
p=root/'play.html';s=p.read_text(encoding='utf-8').replace('config.js?v=9','config.js?v=10').replace('common.js?v=9','common.js?v=10').replace('player.js?v=9','player.js?v=10');p.write_text(s,encoding='utf-8')
print('V10 applied. Upload index.html, play.html, player.js, multiplayer-host.js to GitHub.')
