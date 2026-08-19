# Printing ARScav markers

Print [ARScav-markers.pdf](ARScav-markers.pdf) on a **black-and-white laser** printer.

- Set the print dialog to **Actual Size** / **100%**. Do not use “Scale to Fit”.
- Use **normal / best** toner quality, not draft or eco. Gray toner-saving modes wash out tracking features.
- Each square is **10 cm** wide. That size is what the app tracks (`0.10` meters).
- Plain copier paper is fine. Avoid glossy sheets (glare hurts tracking).
- Cut on the crop marks. Tape or place all **12** markers in the play space.
- You only print this set **once**. Every round reuses the same 12 papers.
- Keep them flat and well lit. Wrinkles and dim rooms make ARKit miss them.

The markers are pure black-on-white. Color printers in grayscale mode also work.

Regenerate the PDF after changing marker art:

```bash
.venv/bin/python scripts/generate_markers.py
```
