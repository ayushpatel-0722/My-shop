import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/cache/image_url_optimizer.dart';

void main() {
  const wiki =
      'https://thumb.wikimedia.org/wikipedia/commons/thumb/c/cc/Desk_Setup_%28Unsplash%29.jpg/1920px-Desk_Setup_%28Unsplash%29.jpg?utm_source=x';

  test('a Wikimedia thumbnail is requested at the nearest standard size', () {
    expect(
      ImageUrlOptimizer.forWidth(wiki, 180),
      contains('/250px-Desk_Setup_%28Unsplash%29.jpg?utm_source=x'),
    );
    expect(ImageUrlOptimizer.forWidth(wiki, 400), contains('/500px-'));
    expect(ImageUrlOptimizer.forWidth(wiki, 900), contains('/960px-'));
  });

  test('never enlarges and keeps already-small ones', () {
    final small = wiki.replaceAll('1920px', '500px');
    expect(ImageUrlOptimizer.forWidth(small, 900), small);
    expect(ImageUrlOptimizer.forWidth(wiki, 5000), wiki);
  });

  test('unknown width or host is left alone', () {
    expect(ImageUrlOptimizer.forWidth(wiki, 0), wiki);
    const other = 'https://cdn.example.com/a/1920px-photo.jpg';
    expect(ImageUrlOptimizer.forWidth(other, 100), other);
  });

  test('Unsplash gets a width parameter, only ever smaller', () {
    const u = 'https://images.unsplash.com/photo-1?w=1600&q=80';
    final r = Uri.parse(ImageUrlOptimizer.forWidth(u, 330));
    expect(r.queryParameters['w'], '400');
    expect(r.queryParameters['q'], '80');
    expect(
      ImageUrlOptimizer.forWidth('https://images.unsplash.com/p?w=300', 800),
      'https://images.unsplash.com/p?w=300',
    );
  });
}
