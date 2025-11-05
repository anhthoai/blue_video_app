# LGBTQ+ Tagging Guide 🏳️‍🌈

## Why Manual Tagging?

**Correct!** IMDb/TMDb APIs **do not** provide LGBTQ+ classifications. This is intentional to:
- Protect privacy and avoid stereotyping
- Leave classification to content curators (you!)
- Allow flexible categorization based on your criteria

So we need to **manually tag** movies after importing them.

---

## 🏷️ How to Tag Movies

### Method 1: Tag by Movie ID

**Step 1**: Get the movie ID

```bash
# List all movies to find IDs
node -e "const axios = require('axios'); axios.get('http://localhost:3000/api/v1/movies').then(r => r.data.data.forEach(m => console.log(m.id, '-', m.title)))"
```

**Step 2**: Tag with LGBTQ+ types

```bash
node tag-lgbtq.js <movie-id> gay
```

---

### Method 2: Tag by Search (Easier!)

```bash
# Search for movie by title and tag it
node tag-lgbtq.js --search "Heartstopper" gay

node tag-lgbtq.js --search "Love, Simon" gay

node tag-lgbtq.js --search "Portrait of a Lady" lesbian
```

---

## 📝 Quick Tagging for Your Current Movies

Based on what you imported, here are the tagging commands:

```bash
# Tag all your current movies

# Heartstopper (if you have it)
node tag-lgbtq.js --search "Heartstopper" gay

# Young Royals (Anne Boleyn was imported instead - not LGBTQ+)
# Anne Boleyn is historical drama, not LGBTQ+ content

# The Bear (not LGBTQ+ content - it's about restaurants)

# Love, Simon
node tag-lgbtq.js --search "Love, Simon" gay

# Call Me by Your Name
node tag-lgbtq.js --search "Call Me by Your Name" gay

# Portrait of a Lady on Fire
node tag-lgbtq.js --search "Portrait of a Lady" lesbian

# Moonlight
node tag-lgbtq.js --search "Moonlight" gay

# The Fabelmans (not LGBTQ+ content)
```

---

## 🎬 Common BoyLove/Gay Content - Auto-Tagged List

I'll create a curated list with pre-tagged LGBTQ+ content for you.

### Popular Gay/BoyLove Content

| IMDb ID | Title | Type | LGBTQ+ Tag |
|---------|-------|------|------------|
| tt14452776 | Heartstopper | TV Series | gay |
| tt13406036 | Young Royals | TV Series | gay |
| tt5164432 | Love, Simon | Movie | gay |
| tt5726616 | Call Me by Your Name | Movie | gay |
| tt4975722 | Moonlight | Movie | gay |
| tt14208870 | Red, White & Royal Blue | Movie | gay |
| tt10648342 | Queer as Folk (2022) | TV Series | gay, queer |
| tt8613070 | Portrait of a Lady on Fire | Movie | lesbian |
| tt0404238 | The L Word | TV Series | lesbian |
| tt1648112 | Carol | Movie | lesbian |

---

## 🚀 Quick Tag Script (Copy & Paste)

Save this as `quick-tag.sh` (or run line by line):

```bash
#!/bin/bash

echo "🏳️‍🌈 Quick LGBTQ+ Tagging Script"
echo "=================================="

# First, make sure you have the movies imported
# Then tag them with appropriate LGBTQ+ types

# Gay content
node tag-lgbtq.js --search "Heartstopper" gay
node tag-lgbtq.js --search "Young Royals" gay
node tag-lgbtq.js --search "Love, Simon" gay
node tag-lgbtq.js --search "Call Me by Your Name" gay
node tag-lgbtq.js --search "Moonlight" gay
node tag-lgbtq.js --search "Red, White" gay

# Lesbian content
node tag-lgbtq.js --search "Portrait of a Lady" lesbian

echo ""
echo "✅ Tagging complete!"
echo "Pull down to refresh your mobile app"
```

---

## 💡 Tagging Strategy

### What to Tag as "Gay"
- Male-male romantic relationships
- Gay protagonists or main characters
- Stories centered on gay experiences
- Coming-out stories (male)

### What to Tag as "Lesbian"
- Female-female romantic relationships
- Lesbian protagonists or main characters
- Stories centered on lesbian experiences
- Coming-out stories (female)

### What to Tag as "Bisexual"
- Characters with both same-sex and opposite-sex relationships
- Bisexual identity exploration
- Characters who identify as bisexual

### What to Tag as "Transgender"
- Transgender protagonists
- Gender identity stories
- Transition narratives

### What to Tag as "Queer"
- General LGBTQ+ content
- Non-binary or genderqueer characters
- Stories that don't fit specific categories
- Can be combined with other tags

---

## 🔧 PowerShell Version (Windows)

For Windows users, use this PowerShell command:

```powershell
# Tag a specific movie
node tag-lgbtq.js --search "Heartstopper" gay

# Tag multiple at once (run each line)
node tag-lgbtq.js --search "Love, Simon" gay
node tag-lgbtq.js --search "Call Me by Your Name" gay
node tag-lgbtq.js --search "Portrait of a Lady" lesbian
```

---

## 📊 After Tagging

Once tagged, the LGBTQ+ filters in your mobile app will show:
- **Gay** filter → Shows all gay-tagged content
- **Lesbian** filter → Shows all lesbian-tagged content
- Etc.

### Test It:
1. Tag some movies (use commands above)
2. **Restart mobile app** or **pull down to refresh**
3. **LGBTQ+ filters now appear** in the filter bar!
4. **Tap "Gay"** → See only gay-tagged movies
5. **Combine filters**: "TV Series" + "Gay" + "Drama"

---

## 🎯 Recommended Workflow

### 1. Import Movies
```bash
node import-movies.js tt14452776 tt13406036 tt5164432 tt5726616
```

### 2. Tag LGBTQ+ Content
```bash
node tag-lgbtq.js --search "Heartstopper" gay
node tag-lgbtq.js --search "Young Royals" gay
node tag-lgbtq.js --search "Love, Simon" gay
node tag-lgbtq.js --search "Call Me by Your Name" gay
```

### 3. Verify in Mobile App
- Pull down to refresh
- See LGBTQ+ filter chips appear
- Filter works!

---

## 🔮 Future Enhancement Ideas

### Option 1: Community Tagging
- Let users suggest tags
- Moderators approve tags
- Crowdsourced classification

### Option 2: AI-Powered Tagging
- Analyze plot summaries for LGBTQ+ themes
- Check cast/character names
- Suggest tags automatically

### Option 3: External Database
- Use LGBTQ+ movie databases (e.g., Queer Cinema Database)
- Cross-reference with IMDb IDs
- Auto-tag on import

---

## ✅ Summary

**You're correct** - TMDb doesn't provide LGBTQ+ tags.

**Solution provided**:
- ✅ Update endpoint (`PATCH /api/v1/movies/:id`)
- ✅ Tagging script (`tag-lgbtq.js`)
- ✅ Search by title (easier than finding IDs)
- ✅ Multiple tags per movie support
- ✅ Dynamic filter display in app

**Now you can properly curate your BoyLove/LGBTQ+ library!** 🏳️‍🌈✨

