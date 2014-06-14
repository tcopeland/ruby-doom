/* Add things to a DOOM level   1/7/96
   Requires PC byte order
 */

/*
 * I did not write this code; I got it off the WWW somewhere or another and use it occasionally to read WADs to check my work.  It's not part of the
 * Ruby-DOOM releases.
*/
#include <stdio.h>
#include <assert.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

unsigned char entry[16], thing[10];

void
getdirent (FILE *fp, char lname[9], long int *loffset, long int *lsize)
{
  assert (fread (entry, 1, 16, fp) == 16);
  strncpy (lname, entry+8, 8);
  lname[8] = '\0';
  *loffset = *(long int *)(entry);
  *lsize = *(long int *)(entry+4);
}

void
getthing (FILE *fp, short *x, short *y, short *angle, short *type,
short *options)
{
  assert (fread (thing, 1, 10, fp) == 10);
  *x = *(short *)(thing);
  *y = *(short *)(thing+2);
  *angle = *(short *)(thing+4);
  *type = *(short *)(thing+6);
  *options = *(short *)(thing+8);
}

#define RND_DENOM 2147483648.0
float
rnd ()
{
  double temp = 2.0;
  while (temp < 0.0 || temp >= 1.0)   /* I've seen 1.0 before.... */
    temp = (double)(random ()) / RND_DENOM;
  return (float)temp;
}

short
rndboom (short min, short max)
{
  return min + (short)((rnd () * (max - min + 1)));
}

int
main (int argc, char **argv)
{
  FILE *fp, *outwad;
  unsigned char header[12], *tempthings, level[11][16];
  char wadtype[5], lname[9];
  int btoadd, typetoadd = 2035;
  long int dirstart, numlumps, looper, loffset, lsize, numthings,
    non_thing_size = 0, thingsize, thingoffset, maxsize=0;
  short minx, miny, maxx, maxy;
  if (argc != 2 && argc != 3 && argc != 5 && argc != 6) {
    fprintf (stderr,
"FOOM produces a PWAD to add more things to a DOOM level.\n\
Usage:  foom wadfilename                             to list wad directory\n\
        foom wadfilename levelname                   to list THINGS\n\
        foom wadfilename levelname N outfilename     to add N barrels\n\
        foom wadfilename levelname N outfilename boss   to add N boss shooters\n");
    exit (-1);
  }
  assert (fp = fopen (argv[1], "r"));

  if (!strcmp (argv[5], "boss"))
    typetoadd = 89;

  /* Read header */
  assert (fread (header, 1, 12, fp) == 12);
  assert (!strncmp (header, "IWAD", 4) || !strncmp (header, "PWAD", 4));
  strncpy (wadtype, header, 4);
  wadtype[4] = '\0';
  printf ("%s\n", wadtype);
  numlumps = *(long int *)(header+4);
  printf ("Number of lumps:  %ld\n", numlumps);
  dirstart = *(long int *)(header+8);
  printf ("File offset to start of directory:  %ld\n\n", dirstart);

  /* Scan directory for level*/
  assert (!fseek (fp, dirstart, SEEK_SET));
  for (looper=0;looper<numlumps;looper++) {
    getdirent (fp, lname, &loffset, &lsize);
    if (argc == 2)
      printf ("%8s   Offset %8ld   Size %8ld\n", lname, loffset, lsize);
    else
      if (!strcmp (lname, argv[2]))
        break;
  }
  if (argc == 2)
    exit (0);

  if (strcmp (lname, argv[2])) {
    fprintf (stderr, "Level not found!\n");
    exit (-1);
  }
  printf ("%8s   Offset %8ld\n", lname, loffset);
  memcpy (level[0], entry, 16);
  for (looper=1;looper<11;looper++) {
    getdirent (fp, lname, &loffset, &lsize);
    printf ("%8s   Offset %8ld   Size %8ld\n", lname, loffset, lsize);
    memcpy (level[looper], entry, 16);
    /* First lump is THINGS */
    if (looper == 1) {
      numthings = lsize / 10;
      thingsize = lsize;
      thingoffset = loffset;
    }
    else
      non_thing_size += lsize;
    if (lsize > maxsize)
      maxsize = lsize;
  }
  printf ("\n");

  /* Scan things */
  assert (!fseek (fp, thingoffset, SEEK_SET));
  for (looper=0;looper<numthings;looper++) {
    short x, y, angle, type, options;
    getthing (fp, &x, &y, &angle, &type, &options);
    if (!looper) {
      minx = maxx = x;
      miny = maxy = y;
    } else {
      if (x < minx)
        minx = x;
      if (x > maxx)
        maxx = x;
      if (y < miny)
        miny = y;
      if (y > maxy)
        maxy = y;
    }
    if (argc == 3)
      printf ("x=%hd y=%hd angle=%hd type=%hd options=%hd\n",
        x, y, angle, type, options);
  }
  printf ("X range:  %hd .. %hd    Y range:  %hd .. %hd\n", minx, maxx,
    miny, maxy);

  if (argc == 3)
    exit (0);
  assert (sscanf (argv[3], "%d", &btoadd) == 1);
  assert (btoadd > 0);

  printf ("Adding %d things....\n", btoadd);
  assert (outwad = fopen (argv[4], "w"));

  /* Write header for out wad */
  header[0] = 'P';
  *(long int *)(header+4) = 11;  /* 11 lumps */
  *(long int *)(header+8) = 12 + (numthings + btoadd) * 10
                               + non_thing_size; /* dirstart */
  assert (fwrite (header, 1, 12, outwad) == 12);

  /* Copy things from old wad */
  assert (tempthings = (unsigned char *) malloc (maxsize));
  assert (!fseek (fp, thingoffset, SEEK_SET));
  assert (fread (tempthings, 1, thingsize, fp) == thingsize);
  assert (fwrite (tempthings, 1, thingsize, outwad) == thingsize);

  /* Add things */
  /* Code for barrel:  x y angle=0 type=2035 options=7 */
  *(short *)(thing+6) = typetoadd;  /* type */
  *(short *)(thing+8) = 7;     /* options */
  srandom (time (NULL));
  for (looper=0;looper<btoadd;looper++) {
    *(short *)(thing+4) = rndboom (0, 3) * 90;     /* angle */
    *(short *)(thing) = rndboom (minx, maxx);     /* x */
    *(short *)(thing+2) = rndboom (miny, maxy);   /* y */
    if (typetoadd == 89) {
      /* Need spawn spots too */
      *(short *)(thing+6) = rndboom (0, 1) * 2 + 87;
    }
    assert (fwrite (thing, 1, 10, outwad) == 10);
  }

  /* Copy rest of lumps -- the Unofficial Doom Specs say that this
     isn't needed, but it is. */
  for (looper=2;looper<11;looper++) {
    loffset = *(long int *)(level[looper]);
    assert (!fseek (fp, loffset, SEEK_SET));
    lsize = *(long int *)((level[looper])+4);
    assert (fread (tempthings, 1, lsize, fp) == lsize);
    assert (fwrite (tempthings, 1, lsize, outwad) == lsize);
  }

  /* Write directory */
  *(long int *)((level[1])+4) += btoadd * 10;
  loffset = 12;
  for (looper=0;looper<11;looper++) {
    *(long int *)((level[looper])) = loffset;
    loffset += *(long int *)((level[looper])+4);
    assert (fwrite (level[looper], 1, 16, outwad) == 16);
  }

  fclose (fp);
  fclose (outwad);
  exit (0);
}

