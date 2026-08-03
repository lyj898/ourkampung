/* ============================================================
   Plan Your Party — multi-step logic
   ============================================================ */
(function(){
  const form = document.getElementById('plannerForm');
  if(!form) return;

  const steps = Array.from(form.querySelectorAll('.pstep'));
  const TOTAL = 8; // steps 0..7 (8 = success)
  let current = 0;

  const data = {
    event_type:'', child_age:5, pax:'', party_date:'',
    venue_type:'', theme:'', theme_custom:'',
    services:[], budget:'',
    name:'', phone:'', email:'', notes:''
  };

  const stepCount = document.getElementById('stepCount');
  const progressFill = document.getElementById('progressFill');
  const progressList = document.getElementById('progressList');

  /* ---- option selection ---- */
  form.querySelectorAll('[data-field]').forEach(group => {
    const field = group.getAttribute('data-field');
    const multi = group.hasAttribute('data-multi');
    group.querySelectorAll('.opt').forEach(opt => {
      opt.addEventListener('click', () => {
        const val = opt.getAttribute('data-value');
        if(multi){
          opt.classList.toggle('sel');
          data[field] = Array.from(group.querySelectorAll('.opt.sel')).map(o=>o.getAttribute('data-value'));
        } else {
          group.querySelectorAll('.opt').forEach(o=>o.classList.remove('sel'));
          opt.classList.add('sel');
          data[field] = val;
        }
        clearErr(steps[current]);
      });
    });
  });

  /* ---- steppers ---- */
  form.querySelectorAll('[data-stepper]').forEach(st => {
    const field = st.getAttribute('data-stepper');
    const min = +st.getAttribute('data-min'), max = +st.getAttribute('data-max');
    const valEl = st.querySelector('[data-val]');
    st.querySelector('[data-dec]').addEventListener('click', ()=>{ data[field]=Math.max(min, data[field]-1); valEl.textContent=data[field]; });
    st.querySelector('[data-inc]').addEventListener('click', ()=>{ data[field]=Math.min(max, data[field]+1); valEl.textContent=data[field]; });
  });

  /* ---- text/select inputs ---- */
  form.querySelectorAll('input, textarea').forEach(inp => {
    if(inp.name && inp.name in data){
      inp.addEventListener('input', ()=>{ data[inp.name]=inp.value.trim(); clearErr(steps[current]); });
    }
  });

  /* ---- navigation ---- */
  form.querySelectorAll('[data-next]').forEach(b => b.addEventListener('click', ()=>{ if(validate(current)) go(current+1); }));
  form.querySelectorAll('[data-back]').forEach(b => b.addEventListener('click', ()=> go(current-1)));

  function go(n){
    if(n<0 || n>=TOTAL+1) return;
    if(n===7) buildReview();
    steps[current].classList.remove('active');
    current = n;
    steps[current].classList.add('active');
    updateChrome();
    window.scrollTo({top:0, behavior:'smooth'});
    // focus first input if present
    const firstInput = steps[current].querySelector('input:not([type=date]), textarea');
    if(firstInput) setTimeout(()=>firstInput.focus(), 300);
  }

  function updateChrome(){
    stepCount.textContent = current>=8 ? 'All done!' : (current===7 ? 'Review your brief' : `Step ${current+1} of 7`);
    progressFill.style.width = ((Math.min(current,7))/7*100) + '%';
    if(progressList){
      progressList.querySelectorAll('li').forEach(li=>{
        const s = +li.getAttribute('data-step');
        li.classList.remove('active','done');
        if(s < current) { li.classList.add('done'); li.querySelector('.p-dot').innerHTML='<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3"><path d="M20 6L9 17l-5-5"/></svg>'; }
        else { li.querySelector('.p-dot').textContent = s+1; }
        if(s === current) li.classList.add('active');
      });
    }
  }

  /* ---- validation ---- */
  function validate(step){
    let ok = true;
    switch(step){
      case 0: ok = !!data.event_type; break;
      case 1: ok = !!(document.querySelector('[name=pax]').value.trim()); break;
      case 2: ok = !!data.venue_type; break;
      case 3: ok = !!(data.theme || data.theme_custom); break;
      case 4: ok = data.services.length>0; break;
      case 5: ok = !!data.budget; break;
      case 6: ok = !!(data.name && data.phone); break;
      default: ok = true;
    }
    if(!ok) showErr(steps[step]);
    return ok;
  }
  function showErr(stepEl){ const e=stepEl.querySelector('[data-err]'); if(e) e.classList.add('show'); }
  function clearErr(stepEl){ const e=stepEl.querySelector('[data-err]'); if(e) e.classList.remove('show'); }

  /* ---- review ---- */
  function themeText(){ return data.theme_custom ? (data.theme && data.theme!=='Undecided' ? `${data.theme} — ${data.theme_custom}` : data.theme_custom) : (data.theme||'—'); }
  function buildReview(){
    const list = document.getElementById('reviewList');
    const rows = [
      ['Occasion', data.event_type],
      ['Age turning', data.child_age],
      ['Guests', document.querySelector('[name=pax]').value || '—'],
      ['Date', data.party_date || 'Flexible'],
      ['Venue', data.venue_type],
      ['Theme', themeText()],
      ['Services', data.services.join(', ') || '—'],
      ['Budget comfort', data.budget],
      ['Name', data.name],
      ['Contact', data.phone + (data.email? ' · '+data.email : '')],
    ];
    if(data.notes) rows.push(['Notes', data.notes]);
    list.innerHTML = rows.map(([l,v])=>`<div class="review-row"><span class="rl">${l}</span><span class="rv">${escapeHtml(String(v))}</span></div>`).join('');
  }
  function escapeHtml(s){ return s.replace(/[&<>"]/g, c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c])); }

  /* ---- submit (AJAX -> FormSubmit) ---- */
  form.addEventListener('submit', async (e)=>{
    e.preventDefault();
    const submitBtn = steps[7].querySelector('button[type=submit]');
    const payload = {
      _subject: 'New party brief - OurKampung',
      Occasion: data.event_type,
      'Age turning': data.child_age,
      Guests: document.querySelector('[name=pax]').value || 'TBC',
      Date: data.party_date || 'Flexible',
      Venue: data.venue_type,
      Theme: themeText(),
      Services: data.services.join(', ') || '-',
      Budget: data.budget,
      Name: data.name,
      Mobile: data.phone,
      Email: data.email || '-',
      Notes: data.notes || '-'
    };
    const endpoint = window.OK_FORM_ENDPOINT || '';

    if(submitBtn){ submitBtn.dataset.label = submitBtn.innerHTML; submitBtn.disabled = true; submitBtn.textContent = 'Sending...'; }
    const finish = (ok)=>{
      if(submitBtn){ submitBtn.disabled = false; if(submitBtn.dataset.label) submitBtn.innerHTML = submitBtn.dataset.label; }
      if(ok){ go(8); }
      else { alert('Sorry - something went wrong sending your brief. Please try again in a moment.'); }
    };

    // Demo mode: endpoint not configured yet -> show success without delivering.
    if(!endpoint || /YOUR_FORMSUBMIT_ALIAS/.test(endpoint)){
      console.warn('[OurKampung] FormSubmit endpoint not set - showing success without delivering. Set window.OK_FORM_ENDPOINT in js/main.js.');
      finish(true); return;
    }
    try {
      const res = await fetch(endpoint, {
        method:'POST',
        headers:{'Content-Type':'application/json','Accept':'application/json'},
        body: JSON.stringify(payload)
      });
      finish(res.ok);
    } catch(err){ finish(false); }
  });

  updateChrome();
})();
