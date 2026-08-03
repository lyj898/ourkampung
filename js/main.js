/* ---------- config ---------- */
// FormSubmit endpoint. An encrypted alias keeps the destination email OUT of
// the page source. Create one at https://formsubmit.co (enter the destination
// address, confirm the email it sends you, then copy your random endpoint) and
// replace the placeholder below with your alias, e.g.
//   window.OK_FORM_ENDPOINT = 'https://formsubmit.co/ajax/abc123def456';
window.OK_FORM_ENDPOINT = 'https://formsubmit.co/ajax/1aacc4903352135bb0fa38c3987d3abd';

document.addEventListener('DOMContentLoaded', () => {
  // Header scroll state
  const header = document.querySelector('.header');
  if (header){
    const onScroll = () => header.classList.toggle('scrolled', window.scrollY > 12);
    window.addEventListener('scroll', onScroll, {passive:true}); onScroll();
  }

  // Mobile menu
  const burger = document.querySelector('.burger');
  const menu = document.querySelector('.mobile-menu');
  if (burger && menu){
    burger.addEventListener('click', () => {
      const open = menu.classList.toggle('open');
      burger.classList.toggle('open', open);
      document.body.style.overflow = open ? 'hidden' : '';
    });
    menu.querySelectorAll('a').forEach(a => a.addEventListener('click', () => {
      menu.classList.remove('open'); burger.classList.remove('open'); document.body.style.overflow='';
    }));
  }

  // Reveal on scroll
  const io = new IntersectionObserver((entries) => {
    entries.forEach(e => { if(e.isIntersecting){ e.target.classList.add('in'); io.unobserve(e.target); } });
  }, {threshold: 0.12, rootMargin: '0px 0px -40px 0px'});
  document.querySelectorAll('.reveal').forEach(el => io.observe(el));
});
