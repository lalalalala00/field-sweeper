// 게임마다 한 줄 설명, 규칙, 조작법. 어느 페이지에서나 쓸 수 있게 스타일과 번역을 이 파일 안에 둔다.
// NemoRules.show(id): 규칙 창을 띄운다. NemoRules.showOnce(id, after): 처음 들어온 게임이면 띄우고, 닫은 뒤(또는 이미 봤으면 바로) after를 부른다.
// 문구는 한국어가 키이고 [영어, 일본어, 중국어 간체]를 둔다. 앱에 규칙 화면을 만들 때 같은 문구를 Localizable.xcstrings로 옮긴다.
// { text, app: true }로 적은 줄은 앱에만 있는 기능(Apple Pencil 등)이라 웹에서는 보여주지 않는다. 앱으로 옮길 때는 함께 넣는다.
(function () {
  const UNDO = '되돌리기는 초급 무제한, 중급 10회, 고급 5회, 전문가 3회까지 사용할 수 있어요.';
  const RULES = {
    minesweeper: {
      title: 'Field Sweeper',
      line: '숫자를 단서로 지뢰의 위치를 추론하고, 안전한 칸을 모두 여는 논리 퍼즐',
      rules: ['열린 칸의 숫자는 주변 8칸에 숨어 있는 지뢰의 개수를 나타내요.', '지뢰가 없는 칸을 모두 열면 성공하고, 지뢰를 열면 게임이 종료돼요.', '처음 여는 칸과 그 주변 8칸에는 지뢰가 없어요.', '지뢰는 무작위로 놓여서, 가끔은 추측해야 하는 순간이 있을 수 있어요.'],
      howto: ['열기 모드에서는 칸을 누르면 열리고, 깃발 모드에서는 지뢰가 있다고 생각하는 칸에 깃발을 표시할 수 있어요.',
        '물음표 모드에서는 지뢰인지 확실하지 않은 칸에 ?를 표시할 수 있어요.',
        '닫힌 칸은 깃발이나 물음표로 자유롭게 변경할 수 있으며, 같은 표시를 다시 누르면 해제돼요.',
        '물음표가 있는 칸은 열 수 있지만, 깃발이 있는 칸은 깃발을 해제해야 열 수 있어요.',
        '길게 누르면 열기와 깃발 동작을 반대로 사용할 수 있어요. 컴퓨터에서는 마우스 오른쪽 버튼으로 깃발을 표시할 수 있어요.',
        '열린 숫자 칸을 누르면 주변 깃발의 개수가 숫자와 같을 때 나머지 닫힌 칸을 한 번에 열 수 있어요.',
        '게임판이 화면보다 크면 드래그해서 원하는 위치로 이동할 수 있어요.',
        { text: '두 손가락으로 벌리거나 오므리면 게임판을 확대하거나 축소할 수 있어요.', app: true },
        { text: 'Apple Pencil Pro를 쥐거나 Apple Pencil 2세대를 두 번 탭하면 열기와 깃발 모드가 바뀌어요.', app: true }],
    },
    sudoku: {
      title: 'Sudoku',
      line: '가로줄, 세로줄, 3×3 구역에 1부터 9까지의 숫자를 채우는 논리 퍼즐',
      rules: ['가로줄, 세로줄, 굵은 선으로 나뉜 3×3 구역마다 1부터 9까지의 숫자가 한 번씩 들어가야 해요.', '처음부터 주어진 숫자는 변경할 수 없어요.', '모든 문제는 추측 없이 논리적으로 풀 수 있어요.'],
      howto: ['원하는 칸을 선택한 뒤 하단의 숫자 버튼을 누르면 입력돼요. 같은 숫자를 다시 누르면 삭제돼요.',
        '메모 모드를 켜면 가능한 숫자 후보를 칸 안에 작게 표시할 수 있어요.',
        '숫자 버튼 아래의 작은 숫자는 해당 숫자를 앞으로 더 입력할 수 있는 개수를 나타내요.',
        { text: 'iPad에서는 Apple Pencil로 칸을 선택하고 숫자를 입력할 수 있어요.', app: true },
        { text: '칸에 숫자를 손글씨로 쓰면 바로 입력돼요. 메모 모드에서 쓰면 메모로 들어가요.', app: true },
        { text: 'Apple Pencil Pro를 쥐거나 Apple Pencil 2세대를 두 번 탭하면 메모 모드가 켜지고 꺼져요.', app: true },
        { text: '손글씨 입력은 ⋯ 메뉴의 \'펜슬로 숫자 쓰기\'에서 끌 수 있어요.', app: true },
        UNDO],
    },
    shikaku: {
      title: 'Shikaku',
      line: '숫자에 맞춰 판을 여러 개의 사각형으로 나누는 논리 퍼즐',
      rules: ['각 사각형에는 숫자가 정확히 하나씩 들어가야 해요.', '숫자는 해당 사각형을 구성하는 칸의 개수를 의미해요.', '사각형은 정사각형 또는 직사각형으로 만들 수 있어요.', '모든 칸은 하나의 사각형에 속해야 하며, 서로 겹칠 수 없어요.'],
      howto: ['시작 칸에서 끝 칸까지 드래그하면 사각형이 만들어지고, 드래그하는 동안 크기가 모서리에 표시돼요.', '완성된 영역을 빠르게 두 번 누르면 삭제할 수 있어요.', '지우개 모드에서는 영역을 누르거나 문질러서 삭제할 수 있어요.', '숫자 1이 있는 칸은 한 번 누르면 바로 영역이 완성돼요.',
        { text: 'Apple Pencil Pro를 쥐거나 Apple Pencil 2세대를 두 번 탭하면 지우개 모드가 켜지고 꺼져요.', app: true },
        UNDO],
    },
    futoshiki: {
      title: 'Futoshiki',
      line: '칸 사이의 부등호를 지키며 가로줄과 세로줄에 숫자를 채우는 논리 퍼즐',
      rules: ['가로줄과 세로줄마다 1부터 판 크기까지의 숫자가 한 번씩 들어가야 해요.', '칸 사이에 표시된 부등호를 지켜야 해요. 부등호의 뾰족한 쪽이 더 작은 숫자를 가리켜요.', '모든 문제는 추측 없이 논리적으로 풀 수 있어요.'],
      howto: ['원하는 칸을 선택한 뒤 하단의 숫자 버튼을 누르면 입력돼요. 같은 숫자를 다시 누르면 삭제돼요.',
        '메모 모드를 켜면 가능한 숫자 후보를 칸 안에 작게 표시할 수 있어요.',
        '부등호 조건을 위반하거나 같은 가로줄 또는 세로줄에 숫자가 중복되면 빨간색으로 표시돼요.',
        { text: 'iPad에서는 Apple Pencil로 칸을 선택하고 숫자를 입력할 수 있어요.', app: true },
        { text: '칸에 숫자를 손글씨로 쓰면 바로 입력돼요. 메모 모드에서 쓰면 메모로 들어가요.', app: true },
        { text: 'Apple Pencil Pro를 쥐거나 Apple Pencil 2세대를 두 번 탭하면 메모 모드가 켜지고 꺼져요.', app: true },
        { text: '손글씨 입력은 ⋯ 메뉴의 \'펜슬로 숫자 쓰기\'에서 끌 수 있어요.', app: true },
        UNDO],
    },
    calc: {
      title: 'Calc Squares',
      line: '칸 묶음마다 적힌 계산이 맞도록 가로줄과 세로줄에 숫자를 채우는 논리 퍼즐',
      rules: ['가로줄과 세로줄마다 1부터 판 크기까지의 숫자가 한 번씩 들어가야 해요.',
        '굵은 선으로 묶인 칸에는 목표 숫자와 연산이 적혀 있어요. 묶음 안의 숫자를 그 연산으로 계산하면 목표 숫자가 나와야 해요.',
        '빼기와 나누기는 두 칸 묶음에만 있어요. 큰 수에서 작은 수를 빼거나 나누면 되고, 칸 순서는 상관없어요.',
        '같은 가로줄이나 세로줄만 아니면 한 묶음 안에 같은 숫자가 여러 번 들어갈 수 있어요.',
        '숫자 하나만 적힌 한 칸 묶음은 처음부터 정해진 칸이에요.',
        '모든 문제의 정답은 하나뿐이에요.'],
      howto: ['원하는 칸을 선택한 뒤 하단의 숫자 버튼을 누르면 입력돼요. 같은 숫자를 다시 누르면 삭제돼요.',
        '메모 모드를 켜면 가능한 숫자 후보를 칸 안에 작게 표시할 수 있어요.',
        '같은 가로줄 또는 세로줄에 숫자가 중복되면 빨간색으로, 다 채운 묶음의 계산이 틀리면 묶음 이름표가 빨간색으로 표시돼요.',
        UNDO,
        '지옥 난이도는 처음부터 정해진 숫자가 없고, 되돌리기를 쓸 수 없어요.'],
    },
    star: {
      title: 'Star Squares',
      line: '가로줄·세로줄·구역마다 정해진 수의 별을 놓되, 별끼리 닿지 않게 하는 논리 퍼즐',
      rules: ['판은 굵은 선으로 여러 구역으로 나뉘어 있어요.',
        '가로줄, 세로줄, 구역마다 정해진 수만큼 별을 놓아야 해요. 초급부터 고급까지는 1개, 전문가는 2개예요.',
        '별끼리는 상하좌우는 물론 대각선으로도 닿을 수 없어요.',
        '모든 문제의 정답은 하나뿐이에요.'],
      howto: ['칸을 누를 때마다 빈칸, 점, 별 순서로 바뀌어요. 점은 별이 없는 칸을 표시해 두는 용도예요.',
        '빈칸에서 끌면 지나가는 칸에 점이 한꺼번에 찍히고, 점에서 끌면 점이 지워져요.',
        '서로 닿아 있거나 한 줄·구역에 너무 많은 별은 빨간색으로 표시돼요.',
        UNDO],
    },
    mirror: {
      title: 'Mirror Squares',
      line: '거울의 방향을 바꿔 빛이 모든 별을 지나 목적지에 도달하도록 만드는 논리 퍼즐',
      rules: ['빛은 주황색 시작점에서 직진하며, 거울에 닿으면 90도로 방향이 바뀌어요.', '빛이 모든 별을 통과한 뒤 과녁 모양의 목적지에 도착하면 성공이에요.', '양 끝에 못이 박힌 회색 거울은 방향을 바꿀 수 없어요.', '빛이 벽에 부딪히면 그 자리에서 멈춰요.', '모든 문제의 정답은 하나뿐이에요.'],
      howto: ['연보라색 칸의 거울을 누르면 /와 \\ 방향이 전환되고, 빛의 경로가 실시간으로 표시돼요.', '빛이 목적지가 아닌 곳으로 나가거나 벽에 막히면 해당 위치에 ×가 표시돼요.', '현재 조작 횟수와 최소 조작 횟수를 확인할 수 있어요. 최소 횟수에 도전해 보세요.', '되돌리기는 횟수 제한 없이 사용할 수 있지만, 사용할 때마다 조작 횟수에 1회 추가돼요.'],
    },
    pair: {
      title: 'Pair Paths',
      line: '같은 숫자가 적힌 두 칸을 정해진 길이로 연결하는 논리 퍼즐',
      rules: ['같은 숫자가 적힌 두 칸을 하나의 길로 연결해야 해요.', '숫자는 시작 칸과 끝 칸을 포함한 전체 경로의 칸 수를 의미해요.', '길은 상하좌우로만 연결할 수 있으며, 다른 길과 겹치거나 교차할 수 없어요.', '같은 숫자가 여러 개 있다면 원하는 숫자끼리 짝을 지어 연결할 수 있어요.', '중급 난이도부터는 벽을 제외한 모든 칸을 길로 채워야 하며, 정답은 하나뿐이에요.'],
      howto: ['숫자가 있는 칸에서 드래그하면 길이 그려지고, 현재 길이가 3/5처럼 표시돼요.', '지나온 칸으로 드래그하면 길이가 줄어들어요.', '완성하지 않은 길은 끝부분에서 다시 드래그해 이어 그릴 수 있어요.', '그려진 길을 빠르게 두 번 누르면 삭제할 수 있어요.', '숫자가 있는 칸에서 다시 드래그하면 연결된 길을 지우고 새로 그릴 수 있어요.', UNDO],
    },
    switch: {
      title: 'Switch Squares',
      line: '칸을 눌러 가로줄과 세로줄의 불을 바꾸고, 모든 불을 켜는 논리 퍼즐',
      rules: ['칸을 누르면 해당 칸이 속한 가로줄과 세로줄의 불이 모두 반전돼요. 켜진 불은 꺼지고, 꺼진 불은 켜져요.', '누른 칸은 한 번만 반전되며, 같은 칸을 두 번 누르면 원래 상태로 돌아가요.', '모든 불을 켜면 성공이에요.', '고급 난이도부터는 최소 조작 횟수가 표시되며, 지옥 난이도에서는 정해진 횟수 안에 모든 불을 켜야 해요.'],
      howto: ['원하는 칸을 누르면 해당 가로줄과 세로줄의 불이 즉시 반전돼요.', '컴퓨터에서는 칸에 마우스를 올리면 영향을 받는 가로줄과 세로줄이 미리 표시돼요.', '현재 켜진 불의 개수와 조작 횟수는 게임판 아래에서 확인할 수 있어요.', '되돌리기는 횟수 제한 없이 사용할 수 있지만, 사용할 때마다 조작 횟수에 1회 추가돼요.'],
    },
  };

  const T = {
    '규칙': ['Rules', 'ルール', '规则'],
    '조작': ['How to play', '操作', '操作方法'],
    '확인': ['Got it', 'OK', '知道了'],
    '규칙 보기': ['Rules', 'ルールを見る', '查看规则'],
    [UNDO]: ['Undo is unlimited on Beginner; Intermediate allows 10, Advanced 5 and Expert 3.', '元に戻すは初級では無制限、中級は10回、上級は5回、エキスパートは3回まで使えます。', '撤销在初级无限制，中级可用 10 次，高级 5 次，专家 3 次。'],
    // 한 줄 설명
    // 지뢰찾기
    '숫자를 단서로 지뢰의 위치를 추론하고, 안전한 칸을 모두 여는 논리 퍼즐': ['A logic puzzle where you use the numbers to work out where the mines are and open every safe square', '数字を手がかりに地雷の位置を推理し、安全なマスをすべて開ける論理パズル', '以数字为线索推断地雷位置，翻开所有安全格的逻辑谜题'],
    '열린 칸의 숫자는 주변 8칸에 숨어 있는 지뢰의 개수를 나타내요.': ['A number on an open square shows how many mines are hidden in the 8 squares around it.', '開いたマスの数字は、周りの8マスに隠れている地雷の数を表します。', '翻开格上的数字表示周围 8 格中隐藏的地雷数。'],
    '지뢰가 없는 칸을 모두 열면 성공하고, 지뢰를 열면 게임이 종료돼요.': ['Open every square without a mine to win; opening a mine ends the game.', '地雷のないマスをすべて開ければ成功、地雷を開けるとゲーム終了です。', '翻开所有无雷格即成功，翻到地雷则游戏结束。'],
    '처음 여는 칸과 그 주변 8칸에는 지뢰가 없어요.': ['The first square you open and the 8 around it never hold a mine.', '最初に開けるマスとその周りの8マスには地雷がありません。', '第一次翻开的格子及其周围 8 格中没有地雷。'],
    '지뢰는 무작위로 놓여서, 가끔은 추측해야 하는 순간이 있을 수 있어요.': ['Mines are placed at random, so now and then you may have to guess.', '地雷はランダムに置かれるため、ときどき推測が必要な場面があります。', '地雷是随机放置的，偶尔可能需要猜测。'],
    '열기 모드에서는 칸을 누르면 열리고, 깃발 모드에서는 지뢰가 있다고 생각하는 칸에 깃발을 표시할 수 있어요.': ['In Open mode, tap a square to open it; in Flag mode, flag squares you think hide a mine.', '開くモードではマスを押すと開き、旗モードでは地雷があると思うマスに旗を立てられます。', '在翻开模式下点击格子即可翻开；在旗子模式下可在你认为有雷的格子上插旗。'],
    '물음표 모드에서는 지뢰인지 확실하지 않은 칸에 ?를 표시할 수 있어요.': ['In question mode, mark squares you’re unsure about with ?.', 'はてなモードでは、地雷か確信のないマスに?をつけられます。', '在问号模式下，可在不确定是否有雷的格子上标记 ?。'],
    '닫힌 칸은 깃발이나 물음표로 자유롭게 변경할 수 있으며, 같은 표시를 다시 누르면 해제돼요.': ['Closed squares can switch freely between a flag and ?; tapping the same mark again removes it.', '閉じたマスは旗とはてなを自由に切り替えられ、同じ印をもう一度押すと外れます。', '未翻开的格子可在旗子和问号之间自由切换，再次点击相同标记即可取消。'],
    '물음표가 있는 칸은 열 수 있지만, 깃발이 있는 칸은 깃발을 해제해야 열 수 있어요.': ['Squares marked ? can be opened, but a flagged square must be unflagged first.', 'はてなのマスは開けられますが、旗のマスは旗を外さないと開けられません。', '标有问号的格子可以翻开，但插旗的格子需要先取消旗子才能翻开。'],
    '길게 누르면 열기와 깃발 동작을 반대로 사용할 수 있어요. 컴퓨터에서는 마우스 오른쪽 버튼으로 깃발을 표시할 수 있어요.': ['A long press does the opposite of Open or Flag. On a computer, right-click to flag.', '長押しすると開くと旗の動作を逆にして使えます。パソコンではマウスの右ボタンで旗を立てられます。', '长按可反向使用翻开和插旗操作。电脑上可用鼠标右键插旗。'],
    '열린 숫자 칸을 누르면 주변 깃발의 개수가 숫자와 같을 때 나머지 닫힌 칸을 한 번에 열 수 있어요.': ['Tap an open number when its flags match the number to open the remaining closed squares at once.', '周りの旗の数が数字と同じとき、開いた数字のマスを押すと残りの閉じたマスを一度に開けます。', '当周围旗子数与数字相同时，点击已翻开的数字格可一次翻开其余未翻开的格子。'],
    '게임판이 화면보다 크면 드래그해서 원하는 위치로 이동할 수 있어요.': ['When the board is bigger than the screen, drag it to move around.', '盤が画面より大きいときは、ドラッグして好きな位置へ動かせます。', '棋盘比屏幕大时，可拖动到想要的位置。'],
    '두 손가락으로 벌리거나 오므리면 게임판을 확대하거나 축소할 수 있어요.': ['Pinch with two fingers to zoom the board in or out.', '2本の指で広げたりつまんだりすると、盤を拡大・縮小できます。', '用两根手指张开或捏合即可放大或缩小棋盘。'],
    // 스도쿠
    '모든 문제는 추측 없이 논리로 풀려요.': ['Every puzzle can be solved by logic, without guessing.', 'どの問題も推測なしで論理だけで解けます。', '所有题目都能靠逻辑解开，无需猜测。'],
    '가로줄, 세로줄, 3×3 구역에 1부터 9까지의 숫자를 채우는 논리 퍼즐': ['A logic puzzle where you fill each row, column and 3×3 box with the numbers 1 to 9', '横の列、縦の列、3×3のブロックに1から9の数字を入れる論理パズル', '在每行、每列和每个 3×3 宫中填入 1 到 9 的逻辑谜题'],
    '가로줄, 세로줄, 굵은 선으로 나뉜 3×3 구역마다 1부터 9까지의 숫자가 한 번씩 들어가야 해요.': ['Each row, column and bold 3×3 box must hold the numbers 1 to 9 exactly once.', '横の列、縦の列、太線で区切られた3×3のブロックには、1から9の数字が一つずつ入ります。', '每行、每列和粗线围成的 3×3 宫中，1 到 9 必须各出现一次。'],
    '처음부터 주어진 숫자는 변경할 수 없어요.': ['Numbers given at the start can’t be changed.', '最初から与えられた数字は変更できません。', '开局给出的数字不能更改。'],
    '모든 문제는 추측 없이 논리적으로 풀 수 있어요.': ['Every puzzle can be solved with logic alone, no guessing.', 'どの問題も推測なしで論理的に解けます。', '所有题目都能靠逻辑解开，无需猜测。'],
    '원하는 칸을 선택한 뒤 하단의 숫자 버튼을 누르면 입력돼요. 같은 숫자를 다시 누르면 삭제돼요.': ['Select a square, then tap a number button below to enter it. Tap the same number again to delete it.', 'マスを選んで下の数字ボタンを押すと入力されます。同じ数字をもう一度押すと削除されます。', '选中格子后点击下方数字按钮即可输入。再次点击相同数字即可删除。'],
    '메모 모드를 켜면 가능한 숫자 후보를 칸 안에 작게 표시할 수 있어요.': ['Turn on note mode to mark possible candidates small inside a square.', 'メモモードをオンにすると、入りうる数字の候補をマスの中に小さく書けます。', '打开笔记模式，可在格子里用小字标出可能的候选数字。'],
    '숫자 버튼 아래의 작은 숫자는 해당 숫자를 앞으로 더 입력할 수 있는 개수를 나타내요.': ['The small number under each button shows how many more of that number you can enter.', '数字ボタンの下の小さな数字は、その数字をあと何個入れられるかを表します。', '数字按钮下方的小数字表示该数字还能再输入几个。'],
    'iPad에서는 Apple Pencil로 칸을 선택하고 숫자를 입력할 수 있어요.': ['On iPad, you can select squares and enter numbers with Apple Pencil.', 'iPadではApple Pencilでマスを選び、数字を入力できます。', '在 iPad 上可以用 Apple Pencil 选择格子并输入数字。'],
    '칸에 숫자를 손글씨로 쓰면 바로 입력돼요. 메모 모드에서 쓰면 메모로 들어가요.': ['Handwrite a number in a square to enter it. In note mode it goes in as a note.', 'マスに数字を手書きするとそのまま入力されます。メモモードで書くとメモになります。', '在格子里手写数字即可输入。在笔记模式下书写会记为笔记。'],
    'Apple Pencil Pro를 쥐거나 Apple Pencil 2세대를 두 번 탭하면 메모 모드가 켜지고 꺼져요.': ['Squeeze Apple Pencil Pro or double-tap Apple Pencil (2nd generation) to turn note mode on or off.', 'Apple Pencil Proを握るか、Apple Pencil（第2世代）をダブルタップすると、メモモードが切り替わります。', '捏一下 Apple Pencil Pro 或双击 Apple Pencil（第二代）可开关笔记模式。'],
    "손글씨 입력은 ⋯ 메뉴의 '펜슬로 숫자 쓰기'에서 끌 수 있어요.": ['You can turn off handwriting under “Write numbers with Pencil” in the ⋯ menu.', '手書き入力は ⋯ メニューの「ペンシルで数字を書く」でオフにできます。', '可在 ⋯ 菜单的“用 Pencil 写数字”中关闭手写输入。'],
    // 시카쿠
    '숫자에 맞춰 판을 여러 개의 사각형으로 나누는 논리 퍼즐': ['A logic puzzle where you split the board into rectangles that match the numbers', '数字に合わせて盤面をいくつかの四角形に分ける論理パズル', '按照数字把棋盘分成若干个矩形的逻辑谜题'],
    '각 사각형에는 숫자가 정확히 하나씩 들어가야 해요.': ['Each rectangle must contain exactly one number.', 'それぞれの四角形には数字がちょうど一つ入ります。', '每个矩形必须恰好包含一个数字。'],
    '숫자는 해당 사각형을 구성하는 칸의 개수를 의미해요.': ['The number is how many squares make up that rectangle.', '数字はその四角形を作るマスの数です。', '数字表示该矩形包含的格子数。'],
    '사각형은 정사각형 또는 직사각형으로 만들 수 있어요.': ['A rectangle can be a square or an oblong.', '四角形は正方形でも長方形でもかまいません。', '矩形可以是正方形，也可以是长方形。'],
    '모든 칸은 하나의 사각형에 속해야 하며, 서로 겹칠 수 없어요.': ['Every square belongs to one rectangle, and rectangles can’t overlap.', 'すべてのマスはどれか一つの四角形に属し、重なることはできません。', '每个格子都必须属于一个矩形，矩形之间不能重叠。'],
    '시작 칸에서 끝 칸까지 드래그하면 사각형이 만들어지고, 드래그하는 동안 크기가 모서리에 표시돼요.': ['Drag from a start square to an end square to make a rectangle; its size shows in the corner while you drag.', '始点のマスから終点のマスまでドラッグすると四角形ができ、ドラッグ中は大きさが角に表示されます。', '从起点格拖到终点格即可画出矩形，拖动时尺寸会显示在角上。'],
    '완성된 영역을 빠르게 두 번 누르면 삭제할 수 있어요.': ['Double-tap a finished area to delete it.', 'できた領域をすばやく2回押すと削除できます。', '快速双击已完成的区域即可删除。'],
    '지우개 모드에서는 영역을 누르거나 문질러서 삭제할 수 있어요.': ['In eraser mode, tap or rub across areas to delete them.', '消しゴムモードでは、領域を押すかこすって削除できます。', '在橡皮擦模式下，点击或涂抹区域即可删除。'],
    '숫자 1이 있는 칸은 한 번 누르면 바로 영역이 완성돼요.': ['Tap a square with a 1 once to complete its area.', '1のマスは一度押すだけで領域ができあがります。', '数字 1 的格子点一下即可完成区域。'],
    'Apple Pencil Pro를 쥐거나 Apple Pencil 2세대를 두 번 탭하면 지우개 모드가 켜지고 꺼져요.': ['Squeeze Apple Pencil Pro or double-tap Apple Pencil (2nd generation) to turn eraser mode on or off.', 'Apple Pencil Proを握るか、Apple Pencil（第2世代）をダブルタップすると、消しゴムモードが切り替わります。', '捏一下 Apple Pencil Pro 或双击 Apple Pencil（第二代）可开关橡皮擦模式。'],
    'Apple Pencil Pro를 쥐거나 Apple Pencil 2세대를 두 번 탭하면 열기와 깃발 모드가 바뀌어요.': ['Squeeze Apple Pencil Pro or double-tap Apple Pencil (2nd generation) to switch between Open and Flag.', 'Apple Pencil Proを握るか、Apple Pencil（第2世代）をダブルタップすると、開くモードと旗モードが切り替わります。', '捏一下 Apple Pencil Pro 或双击 Apple Pencil（第二代）可在翻开和插旗模式之间切换。'],
    // 후토시키
    '칸 사이의 부등호를 지키며 가로줄과 세로줄에 숫자를 채우는 논리 퍼즐': ['A logic puzzle where you fill each row and column with numbers while keeping the inequality signs between squares', 'マスの間の不等号を守りながら、横の列と縦の列に数字を入れる論理パズル', '遵守格子间的不等号，在每行每列填入数字的逻辑谜题'],
    '가로줄과 세로줄마다 1부터 판 크기까지의 숫자가 한 번씩 들어가야 해요.': ['Each row and column must hold every number from 1 to the board size exactly once.', '横の列と縦の列には、1から盤の大きさまでの数字が一つずつ入ります。', '每行每列必须各出现一次 1 到棋盘大小的数字。'],
    '칸 사이에 표시된 부등호를 지켜야 해요. 부등호의 뾰족한 쪽이 더 작은 숫자를 가리켜요.': ['Follow the signs shown between squares. The pointed side points to the smaller number.', 'マスの間の不等号を守ってください。不等号のとがった側が小さい数字を指します。', '必须遵守格子间的不等号。尖的一侧指向较小的数字。'],
    '부등호 조건을 위반하거나 같은 가로줄 또는 세로줄에 숫자가 중복되면 빨간색으로 표시돼요.': ['A broken sign or a number repeated in a row or column turns red.', '不等号に反したり、同じ横の列や縦の列で数字が重なったりすると赤く表示されます。', '违反不等号或同一行、同一列数字重复时会显示为红色。'],
    // 별네모
    '가로줄·세로줄·구역마다 정해진 수의 별을 놓되, 별끼리 닿지 않게 하는 논리 퍼즐': ['A logic puzzle where you place a set number of stars in every row, column and region without any stars touching', '横・縦の列と区域ごとに決まった数の星を置き、星どうしが接しないようにする論理パズル', '在每行、每列和每个区域放置规定数量的星星，且星星之间互不相邻的逻辑谜题'],
    '판은 굵은 선으로 여러 구역으로 나뉘어 있어요.': ['The board is divided into regions by bold lines.', '盤面は太線でいくつかの区域に分かれています。', '棋盘由粗线分成多个区域。'],
    '가로줄, 세로줄, 구역마다 정해진 수만큼 별을 놓아야 해요. 초급부터 고급까지는 1개, 전문가는 2개예요.': ['Place the set number of stars in every row, column and region: 1 from Beginner to Advanced, 2 on Expert.', '横の列、縦の列、区域ごとに決まった数の星を置きます。初級から上級までは1個、エキスパートは2個です。', '每行、每列和每个区域都要放置规定数量的星星：初级到高级为1颗，专家为2颗。'],
    '별끼리는 상하좌우는 물론 대각선으로도 닿을 수 없어요.': ['Stars can’t touch each other, not even diagonally.', '星どうしは上下左右だけでなく、斜めでも接することはできません。', '星星之间上下左右和斜向都不能相邻。'],
    '칸을 누를 때마다 빈칸, 점, 별 순서로 바뀌어요. 점은 별이 없는 칸을 표시해 두는 용도예요.': ['Each tap cycles a square through empty, dot and star. Dots mark squares you know have no star.', 'マスを押すたびに、空き、点、星の順に変わります。点は星がないマスの目印です。', '每点一下格子，会按空白、点、星星的顺序切换。点用来标记没有星星的格子。'],
    '빈칸에서 끌면 지나가는 칸에 점이 한꺼번에 찍히고, 점에서 끌면 점이 지워져요.': ['Drag from an empty square to dot every square you pass; drag from a dot to clear dots.', '空きマスからドラッグすると通ったマスにまとめて点が付き、点からドラッグすると点が消えます。', '从空白格拖动会在经过的格子上一起打点；从点开始拖动则会清除点。'],
    '서로 닿아 있거나 한 줄·구역에 너무 많은 별은 빨간색으로 표시돼요.': ['Stars that touch, or too many stars in a row, column or region, turn red.', '接している星や、1つの列・区域に多すぎる星は赤く表示されます。', '相邻的星星，或某行、某列、某区域中过多的星星会显示为红色。'],
    // 셈네모
    '칸 묶음마다 적힌 계산이 맞도록 가로줄과 세로줄에 숫자를 채우는 논리 퍼즐': ['A logic puzzle where you fill each row and column with numbers so every cage’s sum works out', 'ブロックごとに書かれた計算が合うように、横と縦の列に数字を入れる論理パズル', '在横行与竖列中填入数字，使每个区块标注的计算成立的逻辑谜题'],
    '굵은 선으로 묶인 칸에는 목표 숫자와 연산이 적혀 있어요. 묶음 안의 숫자를 그 연산으로 계산하면 목표 숫자가 나와야 해요.': ['Each cage outlined in bold shows a target and an operation. The numbers inside, combined with that operation, must make the target.', '太線で囲まれたブロックには目標の数と演算が書かれています。ブロック内の数字をその演算で計算すると目標の数になる必要があります。', '粗线围起的区块标有目标数字和运算。区块内的数字按该运算计算后必须等于目标数字。'],
    '빼기와 나누기는 두 칸 묶음에만 있어요. 큰 수에서 작은 수를 빼거나 나누면 되고, 칸 순서는 상관없어요.': ['Subtraction and division only appear in two-square cages. Take the larger number minus or divided by the smaller; the order of squares doesn’t matter.', '引き算と割り算は2マスのブロックにだけあります。大きい数から小さい数を引くか割ればよく、マスの順番は関係ありません。', '减法和除法只出现在两格区块中。用较大的数减去或除以较小的数即可，格子顺序无关。'],
    '같은 가로줄이나 세로줄만 아니면 한 묶음 안에 같은 숫자가 여러 번 들어갈 수 있어요.': ['A number can repeat inside a cage as long as it isn’t in the same row or column.', '同じ横や縦の列でなければ、1つのブロックに同じ数字が何度入ってもかまいません。', '只要不在同一横行或竖列，同一区块内可以出现相同的数字。'],
    '숫자 하나만 적힌 한 칸 묶음은 처음부터 정해진 칸이에요.': ['A one-square cage showing a single number is already filled in.', '数字が1つだけ書かれた1マスのブロックは、最初から決まっているマスです。', '只写有一个数字的单格区块是一开始就确定的格子。'],
    '같은 가로줄 또는 세로줄에 숫자가 중복되면 빨간색으로, 다 채운 묶음의 계산이 틀리면 묶음 이름표가 빨간색으로 표시돼요.': ['A number repeated in a row or column turns red, and a filled cage whose math is wrong shows its label in red.', '同じ横や縦の列で数字が重なると赤く、埋めたブロックの計算が合わないとブロックのラベルが赤く表示されます。', '同一横行或竖列中数字重复时会显示为红色；填满的区块计算错误时，区块标签会显示为红色。'],
    '지옥 난이도는 처음부터 정해진 숫자가 없고, 되돌리기를 쓸 수 없어요.': ['Hell starts with no numbers filled in, and undo isn’t available.', '地獄は最初から決まっている数字がなく、元に戻すも使えません。', '地狱难度一开始没有任何已知数字，也不能撤销。'],
    // 거울네모
    '거울의 방향을 바꿔 빛이 모든 별을 지나 목적지에 도달하도록 만드는 논리 퍼즐': ['A logic puzzle where you turn mirrors so the light passes every star and reaches the goal', '鏡の向きを変えて、光がすべての星を通り目的地に届くようにする論理パズル', '调整镜子方向，让光穿过所有星星并到达终点的逻辑谜题'],
    '빛은 주황색 시작점에서 직진하며, 거울에 닿으면 90도로 방향이 바뀌어요.': ['Light travels straight from the orange start and turns 90° when it hits a mirror.', '光はオレンジの出発点からまっすぐ進み、鏡に当たると90度向きが変わります。', '光从橙色起点笔直射出，碰到镜子会转 90 度。'],
    '빛이 모든 별을 통과한 뒤 과녁 모양의 목적지에 도착하면 성공이에요.': ['You win when the light passes every star and then reaches the target-shaped goal.', '光がすべての星を通ったあと、的の形の目的地に着けば成功です。', '光穿过所有星星后到达靶心形状的终点即成功。'],
    '양 끝에 못이 박힌 회색 거울은 방향을 바꿀 수 없어요.': ['Gray mirrors pinned at both ends can’t be turned.', '両端にピンのある灰色の鏡は向きを変えられません。', '两端带钉的灰色镜子不能改变方向。'],
    '빛이 벽에 부딪히면 그 자리에서 멈춰요.': ['Light stops where it hits a wall.', '光は壁に当たるとそこで止まります。', '光碰到墙就会停在那里。'],
    '모든 문제의 정답은 하나뿐이에요.': ['Every puzzle has exactly one solution.', 'どの問題も答えは一つだけです。', '每道题都只有一个答案。'],
    '연보라색 칸의 거울을 누르면 /와 \\ 방향이 전환되고, 빛의 경로가 실시간으로 표시돼요.': ['Tap a mirror on a lilac square to switch between / and \\; the light’s path updates as you go.', '薄紫のマスの鏡を押すと / と \\ の向きが切り替わり、光の道がリアルタイムで表示されます。', '点击淡紫色格子里的镜子可在 / 和 \\ 之间切换，光路会实时显示。'],
    '빛이 목적지가 아닌 곳으로 나가거나 벽에 막히면 해당 위치에 ×가 표시돼요.': ['If the light leaves anywhere but the goal or is blocked by a wall, a × marks the spot.', '光が目的地以外から出たり壁に止められたりすると、その位置に×が表示されます。', '光从终点以外的地方射出或被墙挡住时，该位置会显示 ×。'],
    '현재 조작 횟수와 최소 조작 횟수를 확인할 수 있어요. 최소 횟수에 도전해 보세요.': ['You can see your current moves and the fewest possible. Try to match the fewest.', '今の操作回数と最少操作回数を確認できます。最少回数に挑戦してみましょう。', '可以查看当前步数和最少步数。试着挑战最少步数吧。'],
    '되돌리기는 횟수 제한 없이 사용할 수 있지만, 사용할 때마다 조작 횟수에 1회 추가돼요.': ['Undo has no limit, but each use adds one to your move count.', '元に戻すは回数制限なく使えますが、使うたびに操作回数が1回増えます。', '撤销没有次数限制，但每次使用都会让步数加 1。'],
    // 짝네모
    '같은 숫자가 적힌 두 칸을 정해진 길이로 연결하는 논리 퍼즐': ['A logic puzzle where you link two squares with the same number using a path of set length', '同じ数字が書かれた2マスを、決まった長さの道でつなぐ論理パズル', '用指定长度的路径连接写有相同数字的两个格子的逻辑谜题'],
    '같은 숫자가 적힌 두 칸을 하나의 길로 연결해야 해요.': ['Link the two squares with the same number using one path.', '同じ数字が書かれた2マスを1本の道でつなぎます。', '用一条路径连接写有相同数字的两个格子。'],
    '숫자는 시작 칸과 끝 칸을 포함한 전체 경로의 칸 수를 의미해요.': ['The number is how many squares the whole path covers, including the start and end.', '数字は始点と終点を含めた道全体のマス数です。', '数字表示包含起点和终点在内的整条路径的格数。'],
    '길은 상하좌우로만 연결할 수 있으며, 다른 길과 겹치거나 교차할 수 없어요.': ['Paths connect only up, down, left and right, and can’t overlap or cross other paths.', '道は上下左右にだけつなげられ、ほかの道と重なったり交差したりできません。', '路径只能上下左右连接，不能与其他路径重叠或交叉。'],
    '같은 숫자가 여러 개 있다면 원하는 숫자끼리 짝을 지어 연결할 수 있어요.': ['If the same number appears several times, you can pair them up however you like.', '同じ数字がいくつもあるときは、好きな組み合わせでつないでかまいません。', '如果同一数字出现多次，可以任意配对连接。'],
    '중급 난이도부터는 벽을 제외한 모든 칸을 길로 채워야 하며, 정답은 하나뿐이에요.': ['From Intermediate on, every square except walls must be filled with paths, and there is only one solution.', '中級からは壁以外のすべてのマスを道で埋める必要があり、答えは一つだけです。', '从中级开始，除墙以外的所有格子都必须用路径填满，答案唯一。'],
    '숫자가 있는 칸에서 드래그하면 길이 그려지고, 현재 길이가 3/5처럼 표시돼요.': ['Drag from a numbered square to draw a path; its current length shows like 3/5.', '数字のマスからドラッグすると道が描かれ、今の長さが3/5のように表示されます。', '从数字格拖动即可画出路径，当前长度会显示为 3/5 这样的形式。'],
    '지나온 칸으로 드래그하면 길이가 줄어들어요.': ['Drag back over squares you passed to shorten the path.', '通ってきたマスにドラッグすると道が短くなります。', '拖回走过的格子可以缩短路径。'],
    '완성하지 않은 길은 끝부분에서 다시 드래그해 이어 그릴 수 있어요.': ['Drag from the end of an unfinished path to keep drawing it.', '描きかけの道は、端から再びドラッグして続けて描けます。', '未完成的路径可以从末端再次拖动继续绘制。'],
    '그려진 길을 빠르게 두 번 누르면 삭제할 수 있어요.': ['Double-tap a drawn path to delete it.', '描いた道をすばやく2回押すと削除できます。', '快速双击已画好的路径即可删除。'],
    '숫자가 있는 칸에서 다시 드래그하면 연결된 길을 지우고 새로 그릴 수 있어요.': ['Drag from a numbered square again to clear its path and draw a new one.', '数字のマスから再びドラッグすると、つながっていた道を消して新しく描けます。', '从数字格再次拖动，即可清除原路径并重新绘制。'],
    // 스위치네모
    '칸을 눌러 가로줄과 세로줄의 불을 바꾸고, 모든 불을 켜는 논리 퍼즐': ['A logic puzzle where tapping a square flips the lights in its row and column, and you turn every light on', 'マスを押して横の列と縦の列の明かりを切り替え、すべての明かりをつける論理パズル', '点击格子切换所在行和列的灯，把所有灯都点亮的逻辑谜题'],
    '칸을 누르면 해당 칸이 속한 가로줄과 세로줄의 불이 모두 반전돼요. 켜진 불은 꺼지고, 꺼진 불은 켜져요.': ['Tapping a square flips every light in its row and column: lights that are on turn off, and lights that are off turn on.', 'マスを押すと、そのマスがある横の列と縦の列の明かりがすべて反転します。ついている明かりは消え、消えている明かりはつきます。', '点击格子会反转其所在行和列的所有灯：亮的会灭，灭的会亮。'],
    '누른 칸은 한 번만 반전되며, 같은 칸을 두 번 누르면 원래 상태로 돌아가요.': ['The tapped square flips only once, and tapping the same square twice puts everything back.', '押したマスは一度だけ反転し、同じマスを2回押すと元の状態に戻ります。', '被点击的格子只反转一次，同一格子点两次会恢复原状。'],
    '고급 난이도부터는 최소 조작 횟수가 표시되며, 지옥 난이도에서는 정해진 횟수 안에 모든 불을 켜야 해요.': ['From Advanced on, the fewest moves are shown; on Hell you must turn every light on within that many moves.', '上級からは最少操作回数が表示され、地獄では決められた回数以内にすべての明かりをつける必要があります。', '从高级开始会显示最少步数；地狱难度必须在规定步数内点亮所有灯。'],
    '원하는 칸을 누르면 해당 가로줄과 세로줄의 불이 즉시 반전돼요.': ['Tap any square to flip the lights in its row and column right away.', 'マスを押すと、その横の列と縦の列の明かりがすぐに反転します。', '点击任意格子，所在行和列的灯会立即反转。'],
    '컴퓨터에서는 칸에 마우스를 올리면 영향을 받는 가로줄과 세로줄이 미리 표시돼요.': ['On a computer, hovering over a square previews the row and column it will affect.', 'パソコンでは、マスにマウスを乗せると影響を受ける横の列と縦の列が前もって表示されます。', '在电脑上，鼠标悬停在格子上会预先显示受影响的行和列。'],
    '현재 켜진 불의 개수와 조작 횟수는 게임판 아래에서 확인할 수 있어요.': ['The number of lights on and your move count are shown under the board.', '今ついている明かりの数と操作回数は、盤の下で確認できます。', '当前亮灯数量和步数显示在棋盘下方。'],
    '모든 불을 켜면 성공이에요.': ['Turn every light on to win.', 'すべての明かりをつければ成功です。', '点亮所有灯即成功。'],
  };

  const LANGS = ['ko', 'ja', 'zh', 'en'];
  function lang() {
    let pref = 'auto';
    try { pref = JSON.parse(localStorage.getItem('fs:lang')) || 'auto'; } catch {}
    if (pref !== 'auto') return pref;
    for (const l of navigator.languages || [navigator.language]) {
      const base = (l || '').toLowerCase().split('-')[0];
      if (LANGS.includes(base)) return base;
    }
    return 'en';
  }
  const t = key => { const l = lang(), row = T[key]; return l === 'ko' || !row ? key : row[{ en: 0, ja: 1, zh: 2 }[l]]; };
  const esc = s => String(s).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));

  // 페이지마다 색이 달라도(지뢰찾기는 잔디 팔레트) 규칙 창은 어디서나 같은 메모지 색으로 보이게 색을 직접 갖는다.
  // 창 높이는 화면 안으로 묶고, 내용이 길면 창 안에서 스크롤된다.
  const CSS = `.nr-scrim { --nr-bg: #f6f4ec; --nr-ink: #344a39; --nr-soft: #56645a; --nr-scrim: rgba(0, 0, 0, .38);
      position: fixed; inset: 0; z-index: 40; display: flex; align-items: center; justify-content: center;
      padding: max(20px, env(safe-area-inset-top)) max(16px, env(safe-area-inset-right)) max(20px, env(safe-area-inset-bottom)) max(16px, env(safe-area-inset-left));
      background: var(--nr-scrim); animation: nr-fade .2s ease-out; }
    @media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) .nr-scrim { --nr-bg: #151914; --nr-ink: #dce5d6; --nr-soft: #9aa79a; --nr-scrim: rgba(0, 0, 0, .6); } }
    :root[data-theme="dark"] .nr-scrim { --nr-bg: #151914; --nr-ink: #dce5d6; --nr-soft: #9aa79a; --nr-scrim: rgba(0, 0, 0, .6); }
    @keyframes nr-fade { from { opacity: 0; } }
    .nr-card { width: 100%; max-width: 440px; max-height: 100%; overflow-y: auto; overscroll-behavior: contain; -webkit-overflow-scrolling: touch; touch-action: pan-y;
      box-sizing: border-box; padding: 22px; border-radius: 22px; background: var(--nr-bg); color: var(--nr-ink);
      display: flex; flex-direction: column; gap: 14px; font-family: system-ui, -apple-system, "Apple SD Gothic Neo", sans-serif; text-align: left; }
    .nr-card > * { flex: none; }
    .nr-head { display: flex; align-items: center; gap: 10px; }
    .nr-head svg { width: 22px; height: 22px; flex: none; }
    .nr-head h2 { margin: 0; font: 800 20px/1.25 ui-rounded, system-ui, sans-serif; }
    .nr-line { margin: 0; font-size: 15px; line-height: 1.5; }
    .nr-card h3 { margin: 4px 0 0; font-size: 12px; font-weight: 600; letter-spacing: .07em; color: var(--nr-soft); }
    .nr-card ul { margin: 0; padding-left: 1.1em; display: flex; flex-direction: column; gap: 6px; font-size: 14px; line-height: 1.5; }
    .nr-card button { margin-top: 6px; border: 0; border-radius: 12px; padding: 12px 16px; font: 600 15px system-ui, sans-serif; background: var(--nr-ink); color: var(--nr-bg); cursor: pointer; }
    .nr-card button:focus-visible { outline: 2px solid var(--nr-ink); outline-offset: 2px; }`;
  function ensureStyle() {
    if (document.getElementById('nr-style')) return;
    const s = document.createElement('style');
    s.id = 'nr-style';
    s.textContent = CSS;
    document.head.appendChild(s);
  }

  // 웹에서 보여줄 줄만: 앱 전용 줄({ text, app: true })은 뺀다.
  const web = lines => lines.filter(x => typeof x === 'string');

  function show(id, onClose) {
    const r = RULES[id];
    if (!r) return;
    ensureStyle();
    const el = document.createElement('div');
    el.className = 'nr-scrim';
    const symbol = window.Nemo ? window.Nemo.symbol(id, 'nr-sym') : '';
    el.innerHTML = `<div class="nr-card" role="dialog" aria-modal="true" aria-labelledby="nrTitle">
      <div class="nr-head">${symbol}<h2 id="nrTitle">${esc(r.title)}</h2></div>
      <p class="nr-line">${esc(t(r.line))}</p>
      <h3>${esc(t('규칙'))}</h3><ul>${web(r.rules).map(x => `<li>${esc(t(x))}</li>`).join('')}</ul>
      <h3>${esc(t('조작'))}</h3><ul>${web(r.howto).map(x => `<li>${esc(t(x))}</li>`).join('')}</ul>
      <button type="button">${esc(t('확인'))}</button></div>`;
    const close = () => { el.remove(); document.removeEventListener('keydown', onKey); if (onClose) onClose(); };
    const onKey = e => { if (e.key === 'Escape') close(); };
    el.querySelector('button').onclick = close;
    el.addEventListener('click', e => { if (e.target === el) close(); });
    document.addEventListener('keydown', onKey);
    document.body.appendChild(el);
    el.querySelector('button').focus();
  }

  // 처음 들어온 게임이면 규칙을 한 번 보여준다. 이 기기에서 본 적이 있으면 바로 다음으로 간다.
  function showOnce(id, after) {
    let seen = false;
    try { seen = !!JSON.parse(localStorage.getItem('fs:rules.' + id)); } catch {}
    if (seen) { if (after) after(); return; }
    try { localStorage.setItem('fs:rules.' + id, 'true'); } catch {}
    show(id, after);
  }

  window.NemoRules = { RULES, show, showOnce, t, line: id => (RULES[id] ? t(RULES[id].line) : '') };
})();
