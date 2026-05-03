const MAX_DEPTH = 4

export function buildCompactSelector(el: HTMLElement): string {
  const parts: string[] = []
  let current: HTMLElement | null = el

  for (let i = 0; i < MAX_DEPTH && current && current !== document.body; i++) {
    const tag = current.tagName.toLowerCase()
    const cls = firstMeaningfulClass(current)
    parts.unshift(cls ? `${tag}.${cls}` : tag)
    current = current.parentElement
  }

  return parts.join(' > ')
}

function firstMeaningfulClass(el: HTMLElement): string | null {
  for (const cls of el.classList) {
    if (cls.startsWith('Mui') || cls.startsWith('css-') === false) {
      return cls
    }
  }
  return null
}
