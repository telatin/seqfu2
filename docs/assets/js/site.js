/* SeqFu docs: small progressive enhancements. Every page works without it. */
(function () {
  "use strict";

  var $ = function (sel, root) { return (root || document).querySelector(sel); };
  var $$ = function (sel, root) { return Array.prototype.slice.call((root || document).querySelectorAll(sel)); };

  function escapeHtml(s) {
    return String(s == null ? "" : s).replace(/[&<>"']/g, function (c) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c];
    });
  }

  /* ------------------------------------------------------------ mobile nav */
  function initNav() {
    var btn = $("[data-nav-toggle]"), nav = $("[data-nav]");
    if (!btn || !nav) return;
    btn.addEventListener("click", function () {
      var open = nav.classList.toggle("open");
      btn.setAttribute("aria-expanded", open ? "true" : "false");
    });
  }

  /* ------------------------------------------------------------ search */
  function initSearch() {
    var box = $("[data-search]");
    if (!box) return;
    var input = $("[data-search-input]", box), panel = $("[data-search-results]", box);
    var index = null, loading = null, focused = -1;

    function load() {
      if (index) return Promise.resolve(index);
      if (!loading) {
        loading = fetch(window.SEQFU.searchIndex)
          .then(function (r) { return r.json(); })
          .then(function (data) { index = data.filter(function (d) { return d.title; }); return index; })
          .catch(function () { index = []; return index; });
      }
      return loading;
    }

    function score(d, toks) {
      var title = d.title.toLowerCase();
      var hay = (d.title + " " + d.summary + " " + d.keywords + " " + d.input + " " + d.group + " " + d.type).toLowerCase();
      var s = 0;
      for (var i = 0; i < toks.length; i++) {
        var t = toks[i];
        if (hay.indexOf(t) === -1) return 0;
        if (title === t || title === "seqfu " + t) s += 20;
        else if (title.indexOf(t) !== -1) s += 6;
        else if ((d.keywords || "").toLowerCase().indexOf(t) !== -1) s += 3;
        else s += 1;
      }
      if (d.deprecated) s -= 2;
      return s;
    }

    function highlight(text, tok) {
      var i = text.toLowerCase().indexOf(tok);
      if (!tok || i < 0) return escapeHtml(text);
      return escapeHtml(text.slice(0, i)) + "<mark>" + escapeHtml(text.slice(i, i + tok.length)) + "</mark>" + escapeHtml(text.slice(i + tok.length));
    }

    function render() {
      var q = input.value.trim().toLowerCase();
      if (!q) { panel.hidden = true; return; }
      load().then(function (idx) {
        var toks = q.split(/\s+/).filter(Boolean);
        var hits = idx.map(function (d) { return { d: d, s: score(d, toks) }; })
          .filter(function (h) { return h.s > 0; })
          .sort(function (a, b) { return b.s - a.s; });
        var html = '<div class="search-meta">' + hits.length + " result" + (hits.length === 1 ? "" : "s") + " for “" + escapeHtml(input.value.trim()) + "”</div>";
        hits.slice(0, 8).forEach(function (h) {
          html += '<a class="search-hit" href="' + escapeHtml(h.d.url) + '">' +
            '<span class="search-hit-head"><span class="search-hit-title">' + escapeHtml(h.d.title) + "</span>" +
            '<span class="badge">' + escapeHtml(h.d.type) + "</span>" +
            (h.d.deprecated ? '<span class="badge badge-danger">deprecated</span>' : "") +
            '<span class="small muted">' + escapeHtml(h.d.group) + "</span></span>" +
            '<span class="search-hit-text">' + highlight(h.d.summary || "", toks[0]) + "</span></a>";
        });
        if (!hits.length) html += '<div class="search-empty">Nothing matches. Try a file type (fastq, tsv) or a task (dereplicate, validate, n50).</div>';
        panel.innerHTML = html;
        panel.hidden = false;
        focused = -1;
      });
    }

    function move(delta) {
      var items = $$(".search-hit", panel);
      if (!items.length) return;
      focused = (focused + delta + items.length) % items.length;
      items.forEach(function (el, i) { el.classList.toggle("focused", i === focused); });
      items[focused].scrollIntoView({ block: "nearest" });
    }

    input.addEventListener("focus", load);
    input.addEventListener("input", render);
    input.addEventListener("keydown", function (e) {
      if (e.key === "ArrowDown") { e.preventDefault(); move(1); }
      else if (e.key === "ArrowUp") { e.preventDefault(); move(-1); }
      else if (e.key === "Enter") {
        var items = $$(".search-hit", panel);
        var target = items[focused >= 0 ? focused : 0];
        if (target) { e.preventDefault(); window.location.href = target.getAttribute("href"); }
      } else if (e.key === "Escape") { input.value = ""; panel.hidden = true; input.blur(); }
    });
    document.addEventListener("click", function (e) { if (!box.contains(e.target)) panel.hidden = true; });
    document.addEventListener("keydown", function (e) {
      var tag = (document.activeElement && document.activeElement.tagName) || "";
      if (e.key === "/" && !/INPUT|TEXTAREA|SELECT/.test(tag)) { e.preventDefault(); input.focus(); }
    });
  }

  /* ------------------------------------------------------------ tabs (install box) */
  function initTabs() {
    $$("[data-tabs]").forEach(function (root) {
      var buttons = $$("[data-tab]", root);
      buttons.forEach(function (btn) {
        btn.addEventListener("click", function () {
          var id = btn.getAttribute("data-tab");
          buttons.forEach(function (b) {
            var on = b === btn;
            b.classList.toggle("active", on);
            b.setAttribute("aria-selected", on ? "true" : "false");
          });
          $$("[data-tab-panel]", root).forEach(function (p) { p.hidden = p.getAttribute("data-tab-panel") !== id; });
        });
      });
    });
  }

  /* ------------------------------------------------------------ table of contents */
  function initToc() {
    var toc = $("[data-toc]"), prose = $("[data-prose]");
    if (!toc || !prose) return;
    var heads = $$("h2[id], h3[id]", prose);
    var related = $("#related");
    if (related) heads.push(related);
    if (heads.length < 2) return;
    var list = $("[data-toc-list]", toc), links = [];
    heads.forEach(function (h) {
      var a = document.createElement("a");
      a.href = "#" + h.id;
      a.textContent = h.textContent.replace(/#$/, "").trim();
      if (h.tagName === "H3") a.className = "toc-h3";
      list.appendChild(a);
      links.push(a);
      if (h.id !== "related") {
        var anchor = document.createElement("a");
        anchor.className = "anchor"; anchor.href = "#" + h.id; anchor.textContent = "#";
        anchor.setAttribute("aria-label", "Link to this section");
        h.appendChild(anchor);
      }
    });
    toc.hidden = false;
    if (!("IntersectionObserver" in window)) return;
    var obs = new IntersectionObserver(function (entries) {
      entries.forEach(function (en) {
        if (!en.isIntersecting) return;
        links.forEach(function (l) { l.classList.toggle("active", l.getAttribute("href") === "#" + en.target.id); });
      });
    }, { rootMargin: "-70px 0px -70% 0px" });
    heads.forEach(function (h) { obs.observe(h); });
  }

  /* ------------------------------------------------------------ copy buttons */
  function initCopy() {
    $$(".prose pre").forEach(function (pre) {
      var code = $("code", pre);
      // ```note / ```warning fences have no highlighter: render them as callouts
      if (code && /language-(note|warning)/.test(code.className)) {
        pre.classList.add("note-block");
        return;
      }
      var box = pre.closest(".highlighter-rouge");
      if (!box) {
        box = document.createElement("div");
        box.className = "codeblock";
        pre.parentNode.insertBefore(box, pre);
        box.appendChild(pre);
      }
      if (!navigator.clipboard || $(".copy-btn", box)) return;
      var btn = document.createElement("button");
      btn.type = "button"; btn.className = "copy-btn"; btn.textContent = "Copy";
      btn.addEventListener("click", function () {
        navigator.clipboard.writeText((code || pre).innerText.replace(/\n$/, "")).then(function () {
          btn.textContent = "Copied";
          setTimeout(function () { btn.textContent = "Copy"; }, 1400);
        });
      });
      box.appendChild(btn);
    });
  }

  /* ------------------------------------------------------------ tools catalogue */
  function initCatalog() {
    var root = $("[data-catalog]");
    if (!root) return;
    var cards = $$("[data-tool]", root);
    var params = new URLSearchParams(window.location.search);
    var state = {
      kind: params.get("kind") || "all",
      input: params.get("input") || "any",
      categories: (params.get("category") || "").split(",").filter(Boolean),
      q: params.get("q") || "",
      hideWrapper: params.get("wrappers") === "hide",
      hideDeprecated: params.get("deprecated") !== "show"
    };
    var titles = {
      all: ["Tools", "Every SeqFu core command and utility, filterable by task, input type and kind."],
      core: ["Core tools", "Subcommands of the seqfu binary, invoked as seqfu <command>. Grouped by task."],
      utility: ["Utilities", "Standalone fu-* programs: specialised analyses, helper scripts and compatibility wrappers."]
    };
    var query = $("[data-filter-query]", root);
    var hideW = $('[data-filter-hide="wrapper"]', root), hideD = $('[data-filter-hide="deprecated"]', root);
    query.value = state.q;
    hideW.checked = state.hideWrapper;
    hideD.checked = state.hideDeprecated;

    function matches(card, ignoreCategory) {
      var d = card.dataset;
      if (state.kind !== "all" && d.kind !== state.kind) return false;
      if (state.input !== "any" && d.input.split("|").indexOf(state.input) === -1) return false;
      if (state.hideWrapper && d.wrapper === "true") return false;
      if (state.hideDeprecated && d.deprecated === "true") return false;
      if (!ignoreCategory && state.categories.length && state.categories.indexOf(d.category) === -1) return false;
      var toks = state.q.toLowerCase().split(/\s+/).filter(Boolean);
      for (var i = 0; i < toks.length; i++) if (d.text.indexOf(toks[i]) === -1) return false;
      return true;
    }

    function syncUrl() {
      var p = new URLSearchParams();
      if (state.kind !== "all") p.set("kind", state.kind);
      if (state.input !== "any") p.set("input", state.input);
      if (state.categories.length) p.set("category", state.categories.join(","));
      if (state.q) p.set("q", state.q);
      if (state.hideWrapper) p.set("wrappers", "hide");
      if (!state.hideDeprecated) p.set("deprecated", "show");
      var s = p.toString();
      history.replaceState(null, "", window.location.pathname + (s ? "?" + s : ""));
    }

    function apply() {
      var shown = 0, perCat = {};
      cards.forEach(function (c) {
        var ok = matches(c, false);
        c.hidden = !ok;
        if (ok) shown++;
        if (matches(c, true)) perCat[c.dataset.category] = (perCat[c.dataset.category] || 0) + 1;
      });
      $$("[data-group]", root).forEach(function (g) {
        var n = $$("[data-tool]:not([hidden])", g).length;
        g.hidden = n === 0;
        $("[data-group-count]", g).textContent = n;
      });
      $$("[data-count-category]", root).forEach(function (el) { el.textContent = perCat[el.getAttribute("data-count-category")] || 0; });
      $$("[data-filter-kind]", root).forEach(function (b) { b.classList.toggle("active", b.getAttribute("data-filter-kind") === state.kind); });
      $$("[data-filter-input]", root).forEach(function (b) { b.classList.toggle("active", b.getAttribute("data-filter-input") === state.input); });
      $$("[data-filter-category]", root).forEach(function (b) {
        var on = state.categories.indexOf(b.getAttribute("data-filter-category")) !== -1;
        b.classList.toggle("active", on);
        b.setAttribute("aria-pressed", on ? "true" : "false");
      });
      $("[data-shown-count]", root).textContent = shown;
      $("[data-empty]", root).hidden = shown !== 0;
      var t = titles[state.kind] || titles.all;
      $("[data-catalog-title]", root).textContent = t[0];
      $("[data-catalog-lede]", root).textContent = t[1];
      document.title = t[0] + " | SeqFu";
      syncUrl();
    }

    $$("[data-filter-kind]", root).forEach(function (b) {
      b.addEventListener("click", function () { state.kind = b.getAttribute("data-filter-kind"); apply(); });
    });
    $$("[data-filter-input]", root).forEach(function (b) {
      b.addEventListener("click", function () { state.input = b.getAttribute("data-filter-input"); apply(); });
    });
    $$("[data-filter-category]", root).forEach(function (b) {
      b.addEventListener("click", function () {
        var id = b.getAttribute("data-filter-category"), i = state.categories.indexOf(id);
        if (i === -1) state.categories.push(id); else state.categories.splice(i, 1);
        apply();
      });
    });
    query.addEventListener("input", function () { state.q = query.value.trim(); apply(); });
    hideW.addEventListener("change", function () { state.hideWrapper = hideW.checked; apply(); });
    hideD.addEventListener("change", function () { state.hideDeprecated = hideD.checked; apply(); });
    apply();
  }

  document.addEventListener("DOMContentLoaded", function () {
    initNav(); initSearch(); initTabs(); initToc(); initCopy(); initCatalog();
  });
})();
