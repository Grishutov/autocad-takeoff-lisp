# AutoCAD takeoff LISP

AutoLISP routines for quick quantity checks in AutoCAD (2021 and later). Written with AI assistance and used in my daily takeoff work.

## LL.lsp - quick totals
| Command | Long name | Result |
| --- | --- | --- |
| `LL` | `SUMLEN` | Total length of the selected objects |
| `AS` | `SUMAREA` | Total area of the selected closed objects, hatches and regions |

The result is shown on screen and copied to the clipboard, ready to paste into Excel.

## QTO.lsp - report by layer
| Command | Result |
| --- | --- |
| `QTO` | Count, length (m) and area (m²) of the selected objects by layer, plus TOTAL. Options: **Labels** (L= / A= next to each object), **Excel** (copy to clipboard), **Csv** (save next to the drawing), **Table** (AutoCAD table) |
| `QTOSET` | Drawing units (mm / cm / m), decimals, label text height |

Objects: LINE, ARC, CIRCLE, ELLIPSE, SPLINE, LWPOLYLINE, POLYLINE (2D/3D), HATCH, REGION. Closed objects give perimeter and area; open objects give length only.

## Install
1. `APPLOAD` -> select the .lsp file -> **Load**.
2. To load it on every start, add the file to **Startup Suite** (Contents...) in the same dialog.

## License
MIT - free to use and modify.
