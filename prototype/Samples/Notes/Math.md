# 數學與程式碼

跳到：[行內數學](#行內數學) · [程式碼](#程式碼) · [註腳與清單](#註腳與清單)

## 行內數學

愛因斯坦：$E = mc^2$，畢氏定理 $a^2 + b^2 = c^2$。

Foundation 會弄壞的兩個例子：$a*b*c$ 裡的星號，和 $\{x \mid x > 0\}$ 裡的反斜線。

錢不是數學：這本書 $5，那本 $10。

跳脫的 \$ 不是公式。

## 區塊數學

$$
\int_0^\infty e^{-x^2}\,dx = \frac{\sqrt{\pi}}{2}
$$

$$\sum_{n=1}^{\infty} \frac{1}{n^2} = \frac{\pi^2}{6}$$

$$
\begin{pmatrix} a & b \\ c & d \end{pmatrix}
\begin{pmatrix} x \\ y \end{pmatrix}
=
\begin{pmatrix} ax + by \\ cx + dy \end{pmatrix}
$$

寫錯的公式會標紅而不是整頁壞掉：$\frac{1}{$。

## 程式碼

```swift
struct Reader: View {
    @State private var count = 0
    var body: some View {
        Button("Tap \(count)") { count += 1 } // 註解
    }
}
```

```python
def fib(n: int) -> int:
    return n if n < 2 else fib(n - 1) + fib(n - 2)
```

```
沒有標語言的程式碼區塊：不上色
```

行內 `code` 裡的 $x$ 不算公式：`$x$`。

## 註腳與清單

Margin 用 markdown-it[^1] 解析，數學交給 KaTeX[^katex]。

[^1]: https://github.com/markdown-it/markdown-it
[^katex]: 字型打包在 App 裡，不連網。

- [x] 數學
- [x] 上色
- [ ] 目錄

1. [ ] 有序清單裡的待辦
2. [x] 也可以

| 功能 | 狀態 |
|:--|--:|
| 表格 | ✓ |
| 圖片 | ![](images/diagram.svg) |

~~刪除線~~、**粗體**、*斜體*、自動連結 https://example.com
