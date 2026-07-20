/* ---------- config ---------- */
window.WA_NUMBER = '6580000000'; // OurKampung WhatsApp (placeholder — update to real number)
const WA_NUMBER = window.WA_NUMBER;
function waLink(msg){
  return 'https://wa.me/' + WA_NUMBER + '?text=' + encodeURIComponent(msg || "Hi OurKampung, I'd love help planning my child's party.");
}

document.addEventListener('DOMContentLoaded', () => {
  // Wire all WhatsApp links
  document.querySelectorAll('[data-wa]').forEach(a => {
    a.href = waLink(a.getAttribute('data-wa'));
    a.target = '_blank'; a.rel = 'noopener';
  });

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
