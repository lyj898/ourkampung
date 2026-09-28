/* OurKampung — moving planner. Works back from a moving date to a dated
   checklist based on the moving guide. Runs entirely in the browser;
   nothing is sent anywhere. Guide links come from #plannerLinks, which the
   build fills in and validates, so they can't drift from the real URLs. */
(function () {
  var form = document.getElementById('planner');
  var out = document.getElementById('planOut');
  if (!form || !out) return;

  var LINKS = {};
  try { LINKS = JSON.parse(document.getElementById('plannerLinks').textContent); } catch (e) { LINKS = {}; }

  // d: days relative to moving day (negative = before). w: optional condition.
  var TASKS = [
    { d: -56, t: 'Fix your moving date', x: 'If it’s flexible, avoid month-ends, weekends and school holidays — they book out first.', g: 'moving' },
    { d: -56, t: 'Read your tenancy agreement’s handover clauses', x: 'The end date and notice period, plus anything on cleaning, aircon servicing and repairs.', g: 'tenancy', w: function (o) { return o.rental; } },
    { d: -56, t: 'Get the renovation completion date in writing', x: 'And build in slack — a renovation overrun is the most common reason a moving date slips.', g: 'reno', w: function (o) { return o.reno; } },
    { d: -56, t: 'Inspect the BTO and report defects before renovation starts', x: 'If you haven’t already: tap the tiles, test every point and tap, and photograph everything.', g: 'bto', w: function (o) { return o.bto; } },
    { d: -56, t: 'Get two or three moving quotes', x: 'Ask for a site survey, in person or by video, rather than a phone estimate.', g: 'moving' },
    { d: -49, t: 'Decide what isn’t coming with you', x: 'Sell, donate or arrange disposal now, so you don’t pay to pack and move it.', g: 'moving' },
    { d: -42, t: 'Book your movers', x: 'Get the date, arrival window and price in writing.', g: 'moving' },
    { d: -42, t: 'Book the service lift at the condo you’re leaving', x: 'Management usually needs notice, a form and a refundable deposit.', g: 'moveDay', w: function (o) { return o.from === 'condo'; } },
    { d: -42, t: 'Book the service lift at your new condo', x: 'Moving in needs its own booking, deposit and time slot.', g: 'moveDay', w: function (o) { return o.to === 'condo'; } },
    { d: -35, t: 'Arrange internet at the new home', x: 'Installation appointments can take a while to get.' },
    { d: -35, t: 'Open a utilities account for the new home', x: 'And arrange to close or transfer the old one. Allow a few working days.', w: function (o) { return !o.rental; } },
    { d: -35, t: 'Open a utilities account for the new home', x: 'But leave the rental’s account open. Under CEA’s template tenancy agreement, power and water stay on for the handover inspection and the landlord closes the account afterwards.', g: 'tenancy', w: function (o) { return o.rental; } },
    { d: -28, t: 'Start packing what you won’t miss', x: 'Books, out-of-season clothes, decorations and rarely used kitchen things.', g: 'moving' },
    { d: -28, t: 'Do the repairs you’re responsible for', x: 'Nail holes, dripping taps, mouldy sealant, blown bulbs and loose hinges.', g: 'fixes', w: function (o) { return o.rental; } },
    { d: -21, t: 'Check the renovation for defects before the final payment', x: 'Tiles, carpentry, paint, drainage and every power point — send the contractor one dated list.', g: 'reno', w: function (o) { return o.reno; } },
    { d: -14, t: 'Pack in earnest, room by room', x: 'Label each box with its room and what’s inside, and pack an “open first” box.', g: 'moving' },
    { d: -14, t: 'Book a clean of the new home for before the furniture arrives', x: 'An empty home can be cleaned properly in a fraction of the time.', w: function (o) { return !o.reno; } },
    { d: -14, t: 'Book the post-renovation clean', x: 'For after every trade has finished, and before the furniture arrives.', g: 'reno', w: function (o) { return o.reno; } },
    { d: -14, t: 'Book the move-out clean', x: 'For after your things are out — it’s what the handover inspection looks at.', g: 'tenancy', w: function (o) { return o.rental; } },
    { d: -14, t: 'Arrange disposal for large items', x: 'Bulky items usually need a booked collection.' },
    { d: -14, t: 'Start updating your address', x: 'Banks, insurers, your employer, schools, your GP and subscriptions.' },
    { d: -10, t: 'Service the aircon if it’s due', x: 'Many tenancy agreements require it. Keep the receipt.', g: 'aircon', w: function (o) { return o.rental; } },
    { d: -10, t: 'Wipe and recycle old electronics', x: 'Back up, sign out of your accounts, remove SIM cards, then factory reset.', g: 'ewaste' },
    { d: -7, t: 'Confirm the details with your movers', x: 'Access, parking, lift arrangements and the time window.', g: 'moveDay' },
    { d: -7, t: 'Measure your largest items against the lift and doorways', x: 'Sofa, fridge, wardrobe and mattress — including the diagonal.', g: 'moveDay', w: function (o) { return o.from !== 'landed' || o.to !== 'landed'; } },
    { d: -5, t: 'Photograph the cables and take down wall items', x: 'Keep screws and brackets in a labelled bag taped to each item.' },
    { d: -2, t: 'Defrost and dry the fridge', x: 'So it doesn’t leak in the lorry.' },
    { d: -1, t: 'Pack your first-night bag and set aside valuables', x: 'Documents, medication, chargers, toiletries, keys, jewellery and cash travel with you, not on the lorry.' },
    { d: 0, t: 'Photograph the lift and lobby, before and after', x: 'Your evidence if the management office questions the deposit.', g: 'moveDay', w: function (o) { return o.from === 'condo' || o.to === 'condo'; } },
    { d: 0, t: 'Walk through, check for damage, then beds first', x: 'Check the old home is empty and the furniture is undamaged before you sign, and have the beds reassembled first.', g: 'moving' },
    { d: 0, t: 'Note the meter readings at both homes', x: 'Photograph them as a record.' },
    { d: 1, t: 'Move-out clean at the old home', x: 'Once everything is out.', w: function (o) { return o.rental; } },
    { d: 2, t: 'Hand over the rental', x: 'Joint inspection with the utilities still on, photos of every room, meter readings, and every key and access card returned — confirmed in writing.', g: 'tenancy', w: function (o) { return o.rental; } },
    { d: 3, t: 'Report your new address to ICA', x: 'A legal requirement within 28 days of moving, done online.', g: 'moving', deadline: 28 },
    { d: 7, t: 'Ask for your condo moving deposit back', x: 'Once management has inspected the common areas.', g: 'moveDay', w: function (o) { return o.from === 'condo' || o.to === 'condo'; } },
    { d: 7, t: 'Service the aircon at the new home', x: 'If you don’t know when it was last done — especially after renovation, or if the home stood empty.', g: 'aircon' },
    { d: 7, t: 'Start a dated defects list', x: 'Some defects only show up after a few weeks. Report them within the defects liability period.', g: 'bto', w: function (o) { return o.bto; } },
    { d: 14, t: 'Follow up on your deposit', x: 'If there are deductions, ask for an itemised list with quotes or receipts.', g: 'tenancy', w: function (o) { return o.rental; } },
    { d: 14, t: 'Finish updating your address', x: 'Anyone you missed the first time.' }
  ];

  var GROUPS = [
    { max: -42, label: 'Six to eight weeks before' },
    { max: -28, label: 'Four to six weeks before' },
    { max: -14, label: 'Two to four weeks before' },
    { max: -7, label: 'One to two weeks before' },
    { max: -1, label: 'The last few days' },
    { max: 0, label: 'Moving day' },
    { max: Infinity, label: 'After the move' }
  ];

  var fmtShort = new Intl.DateTimeFormat('en-SG', { weekday: 'short', day: 'numeric', month: 'short' });
  var fmtLong = new Intl.DateTimeFormat('en-SG', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' });

  function parseDate(v) { var p = v.split('-'); return new Date(+p[0], +p[1] - 1, +p[2]); }
  function addDays(d, n) { return new Date(d.getFullYear(), d.getMonth(), d.getDate() + n); }
  function today() { var n = new Date(); return new Date(n.getFullYear(), n.getMonth(), n.getDate()); }
  function esc(s) { return String(s).replace(/[&<>"]/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]; }); }

  form.addEventListener('submit', function (e) {
    e.preventDefault();
    var err = document.getElementById('pErr');
    var value = form.elements['date'].value;
    if (!value) { err.hidden = false; form.elements['date'].focus(); return; }
    err.hidden = true;

    var o = {
      from: form.elements['from'].value,
      to: form.elements['to'].value,
      rental: form.elements['rental'].checked,
      bto: form.elements['bto'].checked,
      reno: form.elements['reno'].checked
    };
    var move = parseDate(value);
    var now = today();
    var tasks = TASKS
      .filter(function (t) { return !t.w || t.w(o); })
      .map(function (t, i) { return { t: t, date: addDays(move, t.d), i: i }; });

    var overdue = tasks.filter(function (x) { return x.date < now; }).length;
    var html = '<div class="plan-head"><h2>Your checklist for ' + esc(fmtLong.format(move)) + '</h2>' +
      '<div class="plan-actions"><button type="button" class="btn btn-ghost btn-sm" id="planPrint">Print or save as PDF</button></div></div>';
    if (move < now) {
      html += '<p class="plan-note">That date has already passed, so every task shows as overdue. Here’s the full checklist anyway.</p>';
    } else if (overdue) {
      html += '<p class="plan-note">Your move is close, so ' + overdue + (overdue === 1 ? ' task is' : ' tasks are') +
        ' already overdue. They’re marked — start with those.</p>';
    }

    GROUPS.forEach(function (g, gi) {
      var lo = gi === 0 ? -Infinity : GROUPS[gi - 1].max;
      var items = tasks.filter(function (x) { return x.t.d > lo && x.t.d <= g.max; });
      if (!items.length) return;
      html += '<section class="plan-group"><h3>' + esc(g.label) + '</h3><ul class="plan-list">';
      items.forEach(function (x) {
        var id = 'task-' + x.i;
        var late = x.date < now;
        var extra = x.t.deadline ? ' Deadline: ' + esc(fmtShort.format(addDays(move, x.t.deadline))) + '.' : '';
        var link = (x.t.g && LINKS[x.t.g]) ? ' <a href="' + esc(LINKS[x.t.g]) + '">See the guide</a>' : '';
        html += '<li class="plan-item' + (late ? ' overdue' : '') + '">' +
          '<input type="checkbox" id="' + id + '">' +
          '<div><span class="plan-date">' + esc(fmtShort.format(x.date)) + (late ? ' — overdue' : '') + '</span>' +
          '<label class="plan-title" for="' + id + '">' + esc(x.t.t) + '</label>' +
          '<p class="plan-detail">' + esc(x.t.x) + extra + link + '</p></div></li>';
      });
      html += '</ul></section>';
    });

    out.innerHTML = html;
    out.hidden = false;
    out.focus();
    out.scrollIntoView({ behavior: 'smooth', block: 'start' });
  });

  out.addEventListener('change', function (e) {
    if (e.target.type === 'checkbox') e.target.closest('.plan-item').classList.toggle('done', e.target.checked);
  });
  out.addEventListener('click', function (e) {
    if (e.target.id === 'planPrint') window.print();
  });
})();
