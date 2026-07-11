// Contact form submission via Web3Forms. No page reload, inline status message.
(function () {
  var form = document.getElementById('contact-form');
  if (!form) return;
  var status = document.getElementById('form-status');
  var submitBtn = form.querySelector('.form-submit');

  form.addEventListener('submit', function (e) {
    e.preventDefault();

    var key = form.querySelector('[name="access_key"]').value;
    if (!key || key === 'YOUR_WEB3FORMS_ACCESS_KEY') {
      status.textContent = 'This form is not fully set up yet. Please email us directly at info@pioneerfedgroup.com.';
      status.className = 'form-status show error';
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
          status.textContent = 'Message sent. We will get back to you within one business day.';
          status.className = 'form-status show success';
        } else {
          throw new Error(json.message || 'Send failed.');
        }
      })
      .catch(function () {
        status.textContent = 'Something went wrong. Please email us directly at info@pioneerfedgroup.com.';
        status.className = 'form-status show error';
      })
      .finally(function () {
        submitBtn.disabled = false;
        submitBtn.textContent = originalText;
      });
  });
})();
