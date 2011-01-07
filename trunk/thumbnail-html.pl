#!/usr/bin/perl

# ******************************************************
# Software name : Make Thumbnail HTML （サムネイルHTML作成）
#
# Copyright (C) INOUE Hirokazu, All Rights Reserved
#     http://oasis.halfmoon.jp/
#
# version 1.0 (2010/June/18)
#
# GNU GPL Free Software
#
# このプログラムはフリーソフトウェアです。あなたはこれを、フリーソフトウェア財
# 団によって発行された GNU 一般公衆利用許諾契約書(バージョン2か、希望によっては
# それ以降のバージョンのうちどれか)の定める条件の下で再頒布または改変することが
# できます。
# 
# このプログラムは有用であることを願って頒布されますが、*全くの無保証* です。
# 商業可能性の保証や特定の目的への適合性は、言外に示されたものも含め全く存在し
# ません。詳しくはGNU 一般公衆利用許諾契約書をご覧ください。
# 
# あなたはこのプログラムと共に、GNU 一般公衆利用許諾契約書の複製物を一部受け取
# ったはずです。もし受け取っていなければ、フリーソフトウェア財団まで請求してく
# ださい(宛先は the Free Software Foundation, Inc., 59 Temple Place, Suite 330
# , Boston, MA 02111-1307 USA)。
#
# http://www.opensource.jp/gpl/gpl.ja.html
# ******************************************************

use strict;
use warnings;

use File::Basename;
use Image::ExifTool;
use Image::Size;

my ($strTemp, $i);	# ワーキング用変数
my $strThumbDir;	# サムネイル画像が格納されたディレクトリ（ユーザ指定）
my @arrFileStat;	# stat関数でファイル属性を得るときに利用する
my $exifInfo;		# Image::ExifTool->ImageInfoでexifデータを読み込むときに利用する
my @tm;			# UNIX時間（秒）を年月日・時分秒に分離するときに利用する
my @arrFileList;	# grob関数でディレクトリ内のファイル一覧を読み込むときに利用する
my (@arrData, @arrDataSort);	# ファイル名、解像度、撮影日時の配列
my @arrKnownSuffix = ('.jpg', '.jpeg', '.png', '.gif');	# HTML出力時のファイル名で省略する拡張子


print("サムネイルHTML作成 Perlスクリプト\n\n画像ファイルのある検索パスの指定（相対ディレクトリ。例 photo/*.jpg）\n : ");
$strTemp = <STDIN>;
$strTemp =~ s/\n//g;	# 行末の改行を削除
printf("対象ディレクトリ : %s\n", $strTemp);

print("サムネイル画像ファイルのあるディレクトリの指定（相対ディレクトリ。例 thumb/）\n : ");
$strThumbDir = <STDIN>;
$strThumbDir =~ s/\n//g;	# 行末の改行を削除
printf("対象ディレクトリ : %s\n", $strThumbDir);

# Image::ExifToolのオブジェクトをあらかじめ確保しておく
my $exifTool = new Image::ExifTool;

# 指定されたディレクトリ・検索パス内のファイル一覧を読み出し、配列に格納
@arrFileList = glob($strTemp);

$i = 0;	# ファイル数カウンタ
foreach $strTemp (@arrFileList)
{
	$arrData[$i][0] = $strTemp;	# ファイル名を格納（相対ディレクトリ名付き）

	# 撮影日時
#	$exifTool->Options(DateFormat => '%Y/%m/%d %H:%M:%S');
	$exifTool->Options(DateFormat => '%s');	# 日時形式はUNIX秒を返す
	$exifInfo = $exifTool->ImageInfo($strTemp, 'CreateDate');
	if(defined($exifInfo->{'CreateDate'})){
		# Exifの撮影日時情報
		$arrData[$i][1] = $exifInfo->{'CreateDate'};
	}
	else
	{
		# Exifに日時情報が格納されていなかった場合、ファイルの更新日を用いる
		@arrFileStat = stat($arrData[$i][0]);
		$arrData[$i][1] = $arrFileStat[9];
	}

	# サムネイル画像のX,Yサイズ
	($arrData[$i][2], $arrData[$i][3]) = imgsize($strThumbDir.basename($arrData[$i][0]));
	if(!defined($arrData[$i][2]) || !defined($arrData[$i][3]))
	{
		# 解像度が読み出せない場合は、0を格納
		($arrData[$i][2], $arrData[$i][3]) = (0, 0);
	}

	$i++;
}

if($#arrData < 0)
{
	print("画像ファイルのディレクトリに、対象ファイルが1つも見つかりません\n");
	exit;
}

# 日時で配列全体をソート
@arrDataSort = sort { @$a[1] <=> @$b[1] } @arrData;

print("出力ファイルの指定（例 index.html）: ");
$strTemp = <STDIN>;
$strTemp =~ s/\n//g;	# 行末の改行を削除
printf("出力ファイル : %s\n", $strTemp);

# 出力ファイルを開く
if(!open(fh_out, ">".$strTemp))
{
	print("ファイルに書き込めません\n");
	exit;
}

# HTMLヘッダのファイルへの書き込み
print fh_out <<EOF;
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="ja" lang="ja">
<head>
	<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
	<meta http-equiv="Content-Language" content="ja" />
	<title> </title>
</head>
<body>
EOF

# ファイル一覧（表形式）のファイルへの書き込み
printf fh_out sprintf("<p>ディレクトリ %s, 画像ファイル数 %d</p>\n", dirname($arrDataSort[0][0]), $#arrDataSort+1);
print(fh_out "<table border=\"1\">\n\t<tr>\n\t<th>ファイル名</th><th></th><th>撮影日時</th><th></th>\n\t</tr>\n");

for ($i=0; $i<=$#arrDataSort; $i++)
{
	@tm = localtime($arrDataSort[$i][1]);
	$strTemp = sprintf("%04d/%02d/%02d<br />%02d:%02d:%02d", $tm[5]+1900, $tm[4]+1, $tm[3], $tm[2], $tm[1], $tm[0]);
	if($arrDataSort[$i][2] > 0 && $arrDataSort[$i][3] > 0)
	{
		print fh_out sprintf("\t<tr>\n\t<td>%s</td><td><a href=\"%s\"><img src=\"%s\" width=\"%d\" height=\"%d\" alt=\"\" /></a></td><td>%s</td><td></td>\n\t</tr>\n", basename($arrDataSort[$i][0], @arrKnownSuffix), $arrDataSort[$i][0], $strThumbDir.basename($arrDataSort[$i][0]), $arrDataSort[$i][2], $arrDataSort[$i][3], $strTemp);
	}
	else
	{
		# サムネイル画像のX,Yに値が無い（0）の場合は、テキストリンクにする
		print fh_out sprintf("\t<tr>\n\t<td>%s</td><td><a href=\"%s\">%s</a></td><td>%s</td><td></td>\n\t</tr>\n", basename($arrDataSort[$i][0], @arrKnownSuffix), $arrDataSort[$i][0], basename($arrDataSort[$i][0]), $strTemp);
	}

}

print fh_out <<EOF;
</table>
</body>
</html>
EOF

# 出力ファイルを閉じる
close(fh_out);

# プログラム終了
exit;

