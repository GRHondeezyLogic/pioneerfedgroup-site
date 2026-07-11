// Contact form submission via Web3Forms. No page reload, inline status message.
// Includes basic bot mitigation (honeypot + time trap) and phone format checking.
// None of this can verify someone owns the email they typed in, that would
// require a confirmation-link flow, which is more friction than a simple
// contact form should have.
(function () {
  var form = document.getElementById('contact-form');
  if (!form) return;
  var status = document.getElementById('form-status');
  var submitBtn = form.querySelector('.form-submit');
  var loadedAtField = document.getElementById('f-loaded-at');
  var phoneField = document.getElementById('f-phone');

  if (loadedAtField) loadedAtField.value = String(Date.now());

  function showError(message) {
    status.textContent = message;
    status.className = 'form-status show error';
  }

  form.addEventListener('submit', function (e) {
    e.preventDefault();

    // Time trap: a real person takes at least a couple seconds to fill this out.
    var loadedAt = Number(loadedAtField && loadedAtField.value);
    if (loadedAt && Date.now() - loadedAt < 2000) {
      showError('Please take a moment to review your message before sending.');
      return;
    }

    // Loose phone format check. Only runs if a phone number was entered.
    if (phoneField && phoneField.value.trim()) {
      var digits = phoneField.value.replace(/\D/g, '');
      if (digits.length < 10 || digits.length > 11) {
        showError('Please enter a valid phone number, or leave it blank.');
        phoneField.focus();
        return;
      }
    }

    var hcaptchaField = form.querySelector('[name="h-captcha-response"]');
    if (hcaptchaField && !hcaptchaField.value) {
      showError('Please complete the verification challenge before sending.');
      return;
    }

    var key = form.querySelector('[name="access_key"]').value;
    if (!key || key === 'YOUR_WEB3FORMS_ACCESS_KEY') {
      showError('This form is not fully set up yet. Please email us directly at info@pioneerfedgroup.com.');
      return;
    }

    var originalText = submitBtn.textContent;
    submitBtn.disabled = true;
    submitBtn.textContent = 'Sending...';
    status.className = 'form-status';

    fetch(form.action, {
      method: 'POST',
      headers: { Accept: 'application/json' },
      body: new FormData(form)
    })
      .then(function (res) { return res.json(); })
      .then(function (json) {
        if (json.success) {
          form.reset();
          if (loadedAtField) loadedAtField.value = String(Date.now());
          if (window.hcaptcha) window.hcaptcha.reset();
          status.textContent = 'Message sent. We will get back to you within 24 to 72 hours.';
          status.className = 'form-status show success';
        } else {
          throw new Error(json.message || 'Send failed.');
        }
      })
      .catch(function () {
        showError('Something went wrong. Please email us directly at info@pioneerfedgroup.com.');
      })
      .finally(function () {
        submitBtn.disabled = false;
        submitBtn.textContent = originalText;
      });
  });
})();
