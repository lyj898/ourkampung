/* OurKampung — contact form for the editors. Posts to FormSubmit's AJAX
   endpoint, which the build writes onto the form as data-endpoint. */
(function () {
  var form = document.getElementById('contactForm');
  if (!form) return;
  var err = document.getElementById('cErr');
  var success = document.getElementById('cSuccess');
  var invalidMsg = err.textContent;

  function showError(text) { err.textContent = text; err.hidden = false; }

  form.addEventListener('submit', function (e) {
    e.preventDefault();
    var f = form.elements;
    if (f['_honey'].value) return;

    var name = f['Name'].value.trim();
    var email = f['Email'].value.trim();
    var guide = f['Guide'].value.trim();
    var msg = f['Message'].value.trim();
    if (!name || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email) || !msg) { showError(invalidMsg); return; }
    err.hidden = true;

    var endpoint = form.getAttribute('data-endpoint') || '';
    var btn = form.querySelector('button[type=submit]');
    var label = btn.textContent;
    var finish = function (ok) {
      btn.disabled = false;
      btn.textContent = label;
      if (ok) { form.hidden = true; success.hidden = false; success.focus(); }
      else { showError('Sorry — your message couldn’t be sent. Please try again in a moment.'); }
    };
    // Never report success for a message that wasn't sent.
    if (!/^https:\/\//.test(endpoint)) { finish(false); return; }

    btn.disabled = true;
    btn.textContent = 'Sending…';
    fetch(endpoint, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
      body: JSON.stringify({
        _subject: 'OurKampung: message for the editors (' + location.pathname + ')',
        Name: name, Email: email, Guide: guide || '-', Message: msg
      })
    }).then(function (r) {
      // FormSubmit can answer HTTP 200 with success "false", so read the body.
      return r.json().catch(function () { return {}; }).then(function (d) {
        var ok = r.ok && (d.success === true || d.success === 'true');
        // Counted only once FormSubmit confirms delivery (enhanced measurement's
        // form_submit fires on every attempt). Editor messages aren't leads:
        // OurKampung takes no enquiries, so keep this out of the family's
        // generate_lead counts and don't make it a key event.
        if (ok && typeof window.gtag === 'function') window.gtag('event', 'editor_message', { form_name: 'editors_contact' });
        finish(ok);
      });
    }).catch(function () { finish(false); });
  });
})();
