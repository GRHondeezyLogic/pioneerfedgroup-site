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
    // US/Canada numbers are 10 digits; other countries vary, so allow 5-14.
    var countryField = document.getElementById('f-phone-country');
    if (phoneField && phoneField.value.trim()) {
      var digits = phoneField.value.replace(/\D/g, '');
      var isNanp = !countryField || countryField.value.indexOf('+1 ') === 0;
      var min = isNanp ? 10 : 5;
      var max = isNanp ? 11 : 14;
      if (digits.length < min || digits.length > max) {
        showError('Please enter a valid phone number, or leave it blank.');
        phoneField.focus();
        return;
      }
    }

    // Loose zip check. Only runs if a zip was entered: 5 digits or ZIP+4.
    var zipField = document.getElementById('f-zip');
    if (zipField && zipField.value.trim() && !/^\d{5}(-?\d{4})?$/.test(zipField.value.trim())) {
      showError('Please enter a valid zip code, or leave it blank.');
      zipField.focus();
      return;
    }

    // Reject obviously fake/profane email domains (e.g. troll addresses).
    // This only stops casual abuse through the visible form; it cannot
    // catch someone posting directly to the API.
    var emailField = document.getElementById('f-email');
    if (emailField && emailField.value.indexOf('@') !== -1) {
      var domain = emailField.value.split('@')[1].toLowerCase();
      var blocked = ['fuck', 'shit', 'bitch', 'cunt', 'dick', 'cock', 'pussy', 'whore', 'slut', 'asshole', 'nigger', 'faggot', 'retard', 'rape'];
      for (var bi = 0; bi < blocked.length; bi++) {
        if (domain.indexOf(blocked[bi]) !== -1) {
          showError('Please enter a valid email address.');
          emailField.focus();
          return;
        }
      }
    }

    // hCaptcha check. The widget is injected by the Web3Forms client script;
    // its token lands in a textarea named h-captcha-response. Web3Forms
    // rejects submissions without a valid token once hCaptcha is enabled in
    // the dashboard, so catch the empty case here with a friendlier message.
    var hcaptchaField = form.querySelector('textarea[name="h-captcha-response"]');
    if (!hcaptchaField || !hcaptchaField.value) {
      showError('Please check the "I am human" box before sending.');
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

    // Skip the country code in the email when no phone number was given,
    // so the select's default (+1 United States) doesn't show up as noise.
    var formData = new FormData(form);
    if (!phoneField || !phoneField.value.trim()) {
      formData.delete('country_code');
    }

    fetch(form.action, {
      method: 'POST',
      headers: { Accept: 'application/json' },
      body: formData
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
      .catch(function (err) {
        console.error('Contact form submission failed:', err);
        showError('Something went wrong. Please email us directly at info@pioneerfedgroup.com.');
      })
      .finally(function () {
        submitBtn.disabled = false;
        submitBtn.textContent = originalText;
      });
  });
})();
