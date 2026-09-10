/* ============================================
   pages/servicios.js
   Revela cada bloque de categoria al hacer scroll; las tarjetas
   dentro de cada bloque se escalonan con --stagger (ver
   assets/css/pages/servicios.css), aplicado desde data-stagger
   por applyStaggerVars() abajo. Tambien controla el nav de
   pildoras de categoria: scroll suave al hacer click y resaltado
   automatico (scroll-spy) segun la seccion visible.
   ============================================ */
(function () {
    document.querySelectorAll("[data-stagger]").forEach((el) => {
        el.style.setProperty("--stagger", el.dataset.stagger);
    });

    const serviceReveals = document.querySelectorAll('[data-reveal]');
    if ('IntersectionObserver' in window && serviceReveals.length) {
        const serviceObserver = new IntersectionObserver((entries) => {
            entries.forEach((entry) => {
                if (entry.isIntersecting) {
                    entry.target.classList.add('is-visible');
                    serviceObserver.unobserve(entry.target);
                }
            });
        }, { threshold: 0, rootMargin: '0px 0px -12% 0px' });
        serviceReveals.forEach((target) => serviceObserver.observe(target));
    } else {
        serviceReveals.forEach((target) => target.classList.add('is-visible'));
    }

    const catnavPills = document.querySelectorAll('.services-catnav-pill');
    if (catnavPills.length) {
        const catSections = Array.from(catnavPills)
            .map((pill) => document.getElementById(pill.dataset.catnavTarget))
            .filter(Boolean);

        function setActivePill(id) {
            catnavPills.forEach((pill) => {
                pill.classList.toggle('is-active', pill.dataset.catnavTarget === id);
            });
        }

        catnavPills.forEach((pill) => {
            pill.addEventListener('click', (event) => {
                const target = document.getElementById(pill.dataset.catnavTarget);
                if (!target) return;
                event.preventDefault();
                target.scrollIntoView({ behavior: 'smooth', block: 'start' });
                setActivePill(pill.dataset.catnavTarget);
            });
        });

        if ('IntersectionObserver' in window && catSections.length) {
            const spyObserver = new IntersectionObserver((entries) => {
                const visible = entries.filter((entry) => entry.isIntersecting);
                if (!visible.length) return;
                visible.sort((a, b) => b.intersectionRatio - a.intersectionRatio);
                setActivePill(visible[0].target.id);
            }, { rootMargin: '-96px 0px -60% 0px', threshold: [0, 0.25, 0.5, 0.75, 1] });
            catSections.forEach((section) => spyObserver.observe(section));
        }
    }
})();
